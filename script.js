// Datos de ejemplo para productos
let products = [
    {
        id: 1,
        name: "Aceitunas Verdes Rellenas",
        code: "7501254567891",
        category: "Conservas Saladas",
        price: 4.99,
        stock: 24,
        expirationDate: "2023-12-15"
    },
    {
        id: 2,
        name: "Sardinas en Aceite",
        code: "7501254567892",
        category: "Pescados y Mariscos",
        price: 3.50,
        stock: 15,
        expirationDate: "2023-11-30"
    },
    {
        id: 3,
        name: "Salsa de Tomate",
        code: "7501254567893",
        category: "Salsas",
        price: 2.20,
        stock: 30,
        expirationDate: "2024-01-20"
    },
    {
        id: 4,
        name: "Aceite de Oliva",
        code: "7501254567894",
        category: "Aceites",
        price: 8.50,
        stock: 12,
        expirationDate: "2024-03-15"
    },
    {
        id: 5,
        name: "Garbanzos Cocidos",
        code: "7501254567895",
        category: "Legumbres",
        price: 1.80,
        stock: 40,
        expirationDate: "2023-12-10"
    },
    {
        id: 6,
        name: "Atún en Agua",
        code: "7501254567896",
        category: "Pescados y Mariscos",
        price: 2.99,
        stock: 25,
        expirationDate: "2024-02-28"
    },
    {
        id: 7,
        name: "Aceitunas Negras",
        code: "7501254567897",
        category: "Conservas Saladas",
        price: 3.75,
        stock: 18,
        expirationDate: "2023-11-25"
    }
    ];

    // Elementos del DOM
    const productModal = document.getElementById('productModal');
    const productForm = document.getElementById('productForm');
    const cancelBtn = document.getElementById('cancelBtn');
    const closeModal = document.querySelector('.close');

    // Event listeners
    productForm.addEventListener('submit', handleProductSubmit);
    cancelBtn.addEventListener('click', closeProductModal);
    closeModal.addEventListener('click', closeProductModal);
    
    // Cerrar modal al hacer clic fuera de él
    window.addEventListener('click', function(event) {
        if (event.target === productModal) {
            closeProductModal();
        }
    });

// Función para renderizar la tabla de productos
function renderProductsTable() {
    productsTableBody.innerHTML = '';
    
    products.forEach(product => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>
                <div class="product-info">
                    <strong>${product.name}</strong>
                    <small>${product.code}</small>
                </div>
            </td>
            <td>${product.category}</td>
            <td>$${product.price.toFixed(2)}</td>
            <td>${product.stock}</td>
            <td>
                <button class="btn-action" onclick="editProduct(${product.id})"><i class="fas fa-edit"></i></button>
                <button class="btn-action" onclick="deleteProduct(${product.id})"><i class="fas fa-trash"></i></button>
            </td>
        `;
        productsTableBody.appendChild(row);
    });
    }

    // Función para manejar el envío del formulario
function handleProductSubmit(e) {
    e.preventDefault();
    
    const name = document.getElementById('productName').value;
    const code = document.getElementById('productCode').value;
    const category = document.getElementById('productCategory').value;
    const price = parseFloat(document.getElementById('productPrice').value);
    const stock = parseInt(document.getElementById('productStock').value);
    const expirationDate = document.getElementById('expirationDate').value;
    
    // Agregar nuevo producto
    const newId = products.length > 0 ? Math.max(...products.map(p => p.id)) + 1 : 1;
    products.push({
        id: newId,
        name,
        code,
        category: document.getElementById('productCategory').options[document.getElementById('productCategory').selectedIndex].text,
        price,
        stock,
        expirationDate
    });
    
    closeProductModal();
    renderProductsTable();
    
    // Actualizar gráfico
    if (categoryChart) {
        categoryChart.destroy();
        }
    
    // Mostrar mensaje de éxito
    alert('Producto agregado corremente');
}

// Función para cerrar el modal
function closeProductModal() {
    productModal.style.display = 'none';
    productForm.reset();
}

// Función para editar producto (simulada)
function editProduct(id) {
    const product = products.find(p => p.id === id);
    if (product) {
        // En una implementación real, aquí se llenaría el formulario con los datos del producto
        alert(`Editando producto: ${product.name}`);
    }
}

// Función para eliminar producto
function deleteProduct(id) {
    if (confirm('¿Estás seguro de que quieres eliminar este producto?')) {
        products = products.filter(p => p.id !== id);
        renderProductsTable();
        
        // Actualizar gráfico
        if (categoryChart) {
            categoryChart.destroy();
        }
                
        alert('Producto eliminado correctamente');
    }
}

// Simular funcionalidad de filtros
document.querySelectorAll('.filter-btn').forEach(button => {
    button.addEventListener('click', function() {
        document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        this.classList.add('active');
        
        // En una implementación real, aquí se filtrarían los productos
        alert(`Filtrando por: ${this.textContent}`);
    });
});

// Simular funcionalidad de botones de acción
document.querySelectorAll('.btn-action').forEach(button => {
    button.addEventListener('click', function() {
        const action = this.querySelector('i').className;
        if (action.includes('fa-edit')) {
            alert('Editando producto importante');
        } else if (action.includes('fa-trash')) {
            if (confirm('¿Eliminar producto importante?')) {
                alert('Producto importante eliminado');
            }
        } else if (action.includes('fa-chart-line')) {
            alert('Mostrando estadísticas del producto');
        }
    });
    });