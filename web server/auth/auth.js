servidor-auth.js:

const express = require('express');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const app = express();
app.use(express.json());
app.use(cors());
app.use(helmet());


const {
  DB_HOST = 'localhost',
  DB_USER = 'root',
  DB_PASSWORD = 'password',
  DB_NAME = 'inventario',
  DB_PORT = 3306,
  JWT_SECRET = 'cambia-esto-en-produccion',
  JWT_EXPIRES_IN = '12h',
  BCRYPT_ROUNDS = 10
} = process.env;

const pool = mysql.createPool({
  host: DB_HOST,
  user: DB_USER,
  password: DB_PASSWORD,
  database: DB_NAME,
  port: DB_PORT,
  connectionLimit: 10,
  waitForConnections: true
});

// Asegura columnas necesarias sin romper tu esquema actual
async function ensureSchema() {
  const conn = await pool.getConnection();
  try {
    // password_hash para guardar bcrypt. Permite NULL para compatibilidad.
    await conn.query(`
      ALTER TABLE empleados
      ADD COLUMN IF NOT EXISTS password_hash VARCHAR(100) NULL AFTER contrasena_numerica
    `);
    // last_login opcional
    await conn.query(`
      ALTER TABLE empleados
      ADD COLUMN IF NOT EXISTS last_login DATETIME NULL AFTER password_hash
    `);
  } finally {
    conn.release();
  }
}

function signToken(user) {
  return jwt.sign(
    {
      sub: user.id_trabajador,
      dni: user.dni,
      categoria: user.categoria,
      nombre: user.nombre
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
}

async function findUserByDni(dni) {
  const [rows] = await pool.query('SELECT * FROM empleados WHERE dni = ?', [dni]);
  return rows[0];
}

async function countUsers() {
  const [rows] = await pool.query('SELECT COUNT(*) AS total FROM empleados');
  return rows[0].total;
}

// Middleware de protección por Bearer token
function authRequired(req, res, next) {
  const header = req.headers.authorization || '';
  const [, token] = header.split(' ');
  if (!token) return res.status(401).json({ success: false, error: 'Token requerido' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    return next();
  } catch (e) {
    return res.status(401).json({ success: false, error: 'Token inválido o expirado' });
  }
}

// Rate limit básico para endpoints sensibles
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10, // 10 intentos por minuto
  standardHeaders: true,
  legacyHeaders: false
});

// ---------- Rutas ----------

// Health
app.get('/health', (req, res) => {
  res.json({ status: 'OK', service: 'auth' });
});

// Registro
app.post('/api/auth/register', authLimiter, async (req, res) => {
  try {
    const { nombre, apellido_paterno, dni, edad, categoria = 'User', password } = req.body;

    if (!nombre || !apellido_paterno || !dni || !edad || !password) {
      return res.status(400).json({ success: false, error: 'Faltan campos obligatorios' });
    }

    // ¿Existe DNI?
    const existing = await findUserByDni(dni);
    if (existing) {
      return res.status(409).json({ success: false, error: 'DNI ya registrado' });
    }

    // Primera cuenta del sistema => la elevamos a Admin automáticamente
    const total = await countUsers();
    const rolFinal = total === 0 ? 'Admin' : categoria;

    // Hash de la contraseña
    const salt = await bcrypt.genSalt(Number(BCRYPT_ROUNDS));
    const hash = await bcrypt.hash(password, salt);

    // Si te interesa mantener la columna contrasena_numerica:
    // guardamos el valor solo si es exactamente 8 dígitos; si no, NULL
    const contrasenaNumerica = /^\d{8}$/.test(password) ? password : null;

    const [result] = await pool.query(
      `INSERT INTO empleados
       (nombre, apellido_paterno, dni, edad, categoria, contrasena_numerica, password_hash)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [nombre, apellido_paterno, dni, edad, rolFinal, contrasenaNumerica, hash]
    );

    const user = {
      id_trabajador: result.insertId,
      nombre,
      apellido_paterno,
      dni,
      categoria: rolFinal
    };

    const token = signToken(user);
    return res.status(201).json({
      success: true,
      message: 'Usuario registrado',
      data: { id: user.id_trabajador, dni, categoria: rolFinal },
      token
    });
  } catch (err) {
    console.error('Error en register:', err);
    return res.status(500).json({ success: false, error: 'Error al registrar usuario' });
  }
});

// Login
app.post('/api/auth/login', authLimiter, async (req, res) => {
  try {
    const { dni, password } = req.body;
    if (!dni || !password) {
      return res.status(400).json({ success: false, error: 'DNI y password requeridos' });
    }

    const user = await findUserByDni(dni);
    if (!user) return res.status(401).json({ success: false, error: 'Credenciales inválidas' });

    let isValid = false;

    if (user.password_hash) {
      isValid = await bcrypt.compare(password, user.password_hash);
    } else if (user.contrasena_numerica) {
      // Compatibilidad: valida contra la clave numérica
      isValid = password === user.contrasena_numerica;
      // Si valida y no hay hash, hacemos "hash-upgrade" transparente
      if (isValid) {
        const salt = await bcrypt.genSalt(Number(BCRYPT_ROUNDS));
        const hash = await bcrypt.hash(password, salt);
        await pool.query(
          'UPDATE empleados SET password_hash = ?, last_login = NOW() WHERE id_trabajador = ?',
          [hash, user.id_trabajador]
        );
      }
    }

    if (!isValid) return res.status(401).json({ success: false, error: 'Credenciales inválidas' });

    await pool.query('UPDATE empleados SET last_login = NOW() WHERE id_trabajador = ?', [user.id_trabajador]);

    const token = signToken(user);
    return res.json({
      success: true,
      message: 'Login correcto',
      token,
      data: {
        id: user.id_trabajador,
        dni: user.dni,
        categoria: user.categoria,
        nombre: user.nombre
      }
    });
  } catch (err) {
    console.error('Error en login:', err);
    return res.status(500).json({ success: false, error: 'Error al iniciar sesión' });
  }
});

// Perfil (requiere token)
app.get('/api/auth/me', authRequired, async (req, res) => {
  try {
    const user = await findUserByDni(req.user.dni);
    if (!user) return res.status(404).json({ success: false, error: 'Usuario no encontrado' });
    res.json({
      success: true,
      data: {
        id: user.id_trabajador,
        dni: user.dni,
        categoria: user.categoria,
        nombre: user.nombre,
        last_login: user.last_login
      }
    });
  } catch (err) {
    console.error('Error en /me:', err);
    res.status(500).json({ success: false, error: 'Error al obtener perfil' });
  }
});

(async () => {
  try {
    await ensureSchema();
    app.listen(3002, '0.0.0.0', () => {
      console.log('Servidor Auth ejecutándose en puerto 3002');
    });
  } catch (e) {
    console.error('No se pudo iniciar el servicio Auth:', e);
    process.exit(1);
  }
})();
