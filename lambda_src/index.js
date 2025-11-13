// Importar el cliente de SES v3
const { SESClient, SendEmailCommand } = require("@aws-sdk/client-ses");
// Importar el cliente de MySQL (ej. 'mysql2')
const mysql = require("mysql2/promise");

// Crear clientes fuera del handler para reutilizarlos
const sesClient = new SESClient({ region: process.env.AWS_REGION });

// Configuración de la conexión a la BD (tomada de las variables de entorno)
const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
};

/**
 * Handler principal de la Lambda
 */
exports.handler = async (event) => {
  console.log("Evento SQS recibido:", JSON.stringify(event));
  
  // SQS puede enviar múltiples mensajes en un lote
  for (const record of event.Records) {
    try {
      const body = JSON.parse(record.body);
      const tipoAlerta = body.tipo_alerta; // ej: "30_dias", "15_dias"

      console.log(`Procesando alerta tipo: ${tipoAlerta}`);

      // 1. Consultar la base de datos
      const productos = await consultarBaseDeDatos(tipoAlerta);

      // 2. Si hay productos, enviar el correo
      if (productos && productos.length > 0) {
        console.log(`Encontrados ${productos.length} productos para la alerta ${tipoAlerta}`);
        await enviarCorreo(tipoAlerta, productos);
      } else {
        console.log(`No se encontraron productos para la alerta ${tipoAlerta}`);
      }
      
    } catch (error) {
      console.error("Error procesando el registro SQS:", error);
      // Opcional: manejar el error (ej. mover a DLQ)
    }
  }
  
  return { statusCode: 200, body: "Procesado" };
};

/**
 * Función para consultar la base de datos RDS
 */
async function consultarBaseDeDatos(tipoAlerta) {
  let connection;
  try {
    connection = await mysql.createConnection(dbConfig);
    console.log("Conectado a la base de datos.");

    let query = "";
    let queryParams = [];

    // Lógica para construir la consulta basada en el tipo de alerta
    // ESTO ES SOLO UN EJEMPLO - AJUSTA LA CONSULTA A TU ESQUEMA DE BD
    switch (tipoAlerta) {
      case "30_dias":
        // Busca productos que caducan en 30 días O que tienen bajo stock
        query = `
          (SELECT id, nombre, fecha_caducidad, stock FROM productos 
           WHERE fecha_caducidad BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY))
          UNION
          (SELECT id, nombre, fecha_caducidad, stock FROM productos 
           WHERE stock < 10); 
        `;
        // No hay parámetros en este ejemplo, pero podrías tenerlos
        break;
      
      case "15_dias":
        // Lógica similar para 15 días...
        query = `(SELECT id, nombre, fecha_caducidad FROM productos WHERE fecha_caducidad BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 15 DAY))`
        break;
      
      // ... añadir casos para "7_dias" y "1_dia" ...

      default:
        console.warn(`Tipo de alerta desconocido: ${tipoAlerta}`);
        return [];
    }

    // Ejecutar la consulta
    const [rows] = await connection.execute(query, queryParams);
    console.log("Consulta ejecutada con éxito.");
    return rows;

  } catch (error) {
    console.error("Error al conectar o consultar la BD:", error);
    throw error; // Propagar el error para que el handler lo capture
  } finally {
    if (connection) {
      await connection.end();
      console.log("Conexión a la BD cerrada.");
    }
  }
}

/**
 * Función para enviar el correo usando SES
 */
async function enviarCorreo(tipoAlerta, productos) {
  const emailDestino = process.env.ADMIN_EMAIL;
  const emailFuente = "alertas@tu-tienda.com"; // DEBE ser una identidad verificada en SES

  // Construir el cuerpo del correo
  let cuerpoHtml = `<h1>Alerta de Inventario: ${tipoAlerta}</h1>
                    <p>Se encontraron ${productos.length} productos que requieren su atención:</p>
                    <ul>`;
  
  productos.forEach(p => {
    cuerpoHtml += `<li><b>ID ${p.id} - ${p.nombre}</b>: Stock: ${p.stock} | Caduca: ${p.fecha_caducidad}</li>`;
  });

  cuerpoHtml += "</ul><p>Por favor, revise el inventario.</p>";

  // Configuración del comando de envío de SES
  const command = new SendEmailCommand({
    Destination: {
      ToAddresses: [emailDestino],
    },
    Message: {
      Body: {
        Html: {
          Charset: "UTF-8",
          Data: cuerpoHtml,
        },
        Text: {
          Charset: "UTF-8",
          Data: `Se encontraron ${productos.length} productos. Por favor, revise el inventario.`,
        },
      },
      Subject: {
        Charset: "UTF-8",
        Data: `ALERTA de Inventario: ${tipoAlerta}`,
      },
    },
    Source: emailFuente,
  });

  try {
    const response = await sesClient.send(command);
    console.log("Correo enviado con éxito:", response.MessageId);
    return response;
  } catch (error) {
    console.error("Error al enviar correo con SES:", error);
    throw error;
  }
}