// Datos de ejemplo para el dashboard
let inventoryData = {
    products: [
        {
            id: 1,
            name: "Aceitunas Verdes Rellenas",
            category: "Conservas Saladas",
            quantity: 23,
            unit: "latas",
            expiry: "2024-12-19",
            location: "Estante B-2",
            supplier: "Mediterráneo S.A.",
            price: 3.25
        },
        {
            id: 2,
            name: "Atún en Aceite de Oliva",
            category: "Pescados y Mariscos",
            quantity: 67,
            unit: "latas",
            expiry: "2025-06-14",
            location: "Estante C-1",
            supplier: "Pescados del Mar",
            price: 5.99
        },
        {
            id: 3,
            name: "Duraznos en Almíbar",
            category: "Frutas en Conserva",
            quantity: 42,
            unit: "latas",
            expiry: "2025-10-15",
            location: "Estante A-3",
            supplier: "Frutas Selectas",
            price: 4.50
        },
        {
            id: 4,
            name: "Salsa de Tomate",
            category: "Salsas",
            quantity: 35,
            unit: "frascos",
            expiry: "2025-08-22",
            location: "Estante D-1",
            supplier: "Tomates Premium",
            price: 2.75
        },
        {
            id: 5,
            name: "Mermelada de Fresa",
            category: "Conservas Dulces",
            quantity: 14,
            unit: "frascos",
            expiry: "2025-07-05",
            location: "Estante A-2",
            supplier: "Dulces Naturales",
            price: 3.80
        }
    ],
    categories: ["Pescados y Mariscos", "Conservas Dulces", "Frutas en Conserva", "Conservas Saladas", "Salsas"],
    monthlyTrend: [150, 165, 180, 172, 181]
};

// Variables globales
let currentPage = 1;
const productsPerPage = 10;
let currentSort = { column: 'name', direction: 'asc' };
let filteredProducts = [];
let productToDelete = null;
let chartInstances = {};

// Inicialización cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', function() {
    initDashboard();
    setupEventListeners();
});

// Inicializar el dashboard
function initDashboard() {
    filteredProducts = [...inventoryData.products];
    updateSummaryCards();
    renderCharts();
    renderProductTable();
    setupSorting();
}

// Configurar event listeners
function setupEventListeners() {
    // Botón para agregar producto
    document.getElementById('addProduct').addEventListener('click', openProductModal);
    
    // Filtros
    document.getElementById('search').addEventListener('input', filterProducts);
    document.getElementById('filterCategory').addEventListener('change', filterProducts);
    document.getElementById('filterExpiry').addEventListener('change', filterProducts);
    
    // Modal de producto
    document.getElementById('cancelBtn').addEventListener('click', closeProductModal);
    document.getElementById('saveProduct').addEventListener('click', saveProduct);
    document.querySelectorAll('.close-modal').forEach(btn => {
        btn.addEventListener('click', function() {
            closeProductModal();
            closeConfirmModal();
        });
    });
    
    // Modal de confirmación
    document.getElementById('cancelDelete').addEventListener('click', closeConfirmModal);
    document.getElementById('confirmDelete').addEventListener('click', confirmDelete);
    
    // Paginación
    document.getElementById('prevPage').addEventListener('click', goToPrevPage);
    document.getElementById('nextPage').addEventListener('click', goToNextPage);
    
    // Cerrar modal al hacer clic fuera
    window.addEventListener('click', function(event) {
        const productModal = document.getElementById('productModal');
        const confirmModal = document.getElementById('confirmModal');
        
        if (event.target === productModal) {
            closeProductModal();
        }
        
        if (event.target === confirmModal) {
            closeConfirmModal();
        }
    });
    
    // Botones de exportar y filtros avanzados
    document.getElementById('exportBtn').addEventListener('click', exportData);
    document.getElementById('filterBtn').addEventListener('click', showAdvancedFilters);
}

// Configurar ordenamiento de columnas
function setupSorting() {
    document.querySelectorAll('th[data-sort]').forEach(th => {
        th.addEventListener('click', function() {
            const column = this.getAttribute('data-sort');
            sortTable(column);
        });
    });
}

// Ordenar tabla
function sortTable(column) {
    // Resetear indicadores de ordenamiento
    document.querySelectorAll('th[data-sort]').forEach(th => {
        th.classList.remove('sorted-asc', 'sorted-desc');
    });
    
    // Determinar dirección de ordenamiento
    if (currentSort.column === column) {
        currentSort.direction = currentSort.direction === 'asc' ? 'desc' : 'asc';
    } else {
        currentSort.column = column;
        currentSort.direction = 'asc';
    }
    
    // Aplicar ordenamiento
    filteredProducts.sort((a, b) => {
        let aValue = a[column];
        let bValue = b[column];
        
        // Manejar fechas de vencimiento
        if (column === 'expiry') {
            aValue = new Date(aValue);
            bValue = new Date(bValue);
        }
        
        // Manejar cantidades (extraer número)
        if (column === 'quantity') {
            aValue = a.quantity;
            bValue = b.quantity;
        }
        
        // Manejar precios
        if (column === 'price') {
            aValue = a.price;
            bValue = b.price;
        }
        
        if (aValue < bValue) return currentSort.direction === 'asc' ? -1 : 1;
        if (aValue > bValue) return currentSort.direction === 'asc' ? 1 : -1;
        return 0;
    });
    
    // Actualizar indicador visual
    const currentTh = document.querySelector(`th[data-sort="${column}"]`);
    currentTh.classList.add(currentSort.direction === 'asc' ? 'sorted-asc' : 'sorted-desc');
    
    // Volver a la primera página y renderizar
    currentPage = 1;
    renderProductTable();
}

// Filtrar productos
function filterProducts() {
    const searchTerm = document.getElementById('search').value.toLowerCase();
    const categoryFilter = document.getElementById('filterCategory').value;
    const expiryFilter = document.getElementById('filterExpiry').value;
    
    filteredProducts = inventoryData.products.filter(product => {
        // Filtro por búsqueda
        const matchesSearch = product.name.toLowerCase().includes(searchTerm) || 
                             product.category.toLowerCase().includes(searchTerm) ||
                             product.supplier.toLowerCase().includes(searchTerm);
        
        // Filtro por categoría
        const matchesCategory = categoryFilter === 'all' || product.category === categoryFilter;
        
        // Filtro por vencimiento
        const expiryDate = new Date(product.expiry);
        const today = new Date();
        const daysToExpiry = Math.ceil((expiryDate - today) / (1000 * 60 * 60 * 24));
        
        let matchesExpiry = true;
        if (expiryFilter === 'expired') {
            matchesExpiry = daysToExpiry < 0;
        } else if (expiryFilter === 'soon') {
            matchesExpiry = daysToExpiry >= 0 && daysToExpiry <= 30;
        } else if (expiryFilter === 'valid') {
            matchesExpiry = daysToExpiry > 30;
        }
        
        return matchesSearch && matchesCategory && matchesExpiry;
    });
    
    // Volver a la primera página y renderizar
    currentPage = 1;
    renderProductTable();
    updateSummaryCards();
    renderCharts();
}

// Actualizar las tarjetas de resumen
function updateSummaryCards() {
    const totalProducts = filteredProducts.length;
    const totalQuantity = filteredProducts.reduce((sum, product) => sum + product.quantity, 0);
    const inventoryValue = filteredProducts.reduce((sum, product) => sum + (product.price * product.quantity), 0);
    
    // Calcular productos próximos a vencer (en los próximos 30 días)
    const today = new Date();
    const nextMonth = new Date();
    nextMonth.setDate(today.getDate() + 30);
    
    const nextExpire = filteredProducts.filter(product => {
        const expiryDate = new Date(product.expiry);
        return expiryDate > today && expiryDate <= nextMonth;
    }).length;
    
    document.getElementById('totalProducts').textContent = totalProducts;
    document.getElementById('totalQuantity').textContent = totalQuantity;
    document.getElementById('inventoryValue').textContent = `$${inventoryValue.toFixed(2)}`;
    document.getElementById('nextExpire').textContent = nextExpire;
}

// Renderizar gráficos
function renderCharts() {
    renderCategoryChart();
    renderExpiryChart();
    renderTrendChart();
}

// Gráfico de productos por categoría
function renderCategoryChart() {
    const ctx = document.getElementById('categoryChart').getContext('2d');
    
    // Destruir instancia anterior si existe
    if (chartInstances.categoryChart) {
        chartInstances.categoryChart.destroy();
    }
    
    // Calcular productos por categoría
    const categoryCounts = {};
    inventoryData.categories.forEach(category => {
        categoryCounts[category] = 0;
    });
    
    filteredProducts.forEach(product => {
        categoryCounts[product.category] = (categoryCounts[product.category] || 0) + product.quantity;
    });
    
    const data = inventoryData.categories.map(category => categoryCounts[category] || 0);
    
    chartInstances.categoryChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: inventoryData.categories,
            datasets: [{
                data: data,
                backgroundColor: [
                    '#facc15', '#3b82f6', '#a855f7', '#22c55e', '#ef4444'
                ],
                borderWidth: 2,
                borderColor: '#fff'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: {
                        padding: 20,
                        usePointStyle: true
                    }
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            const label = context.label || '';
                            const value = context.raw || 0;
                            const total = context.dataset.data.reduce((a, b) => a + b, 0);
                            const percentage = total > 0 ? Math.round((value / total) * 100) : 0;
                            return `${label}: ${value} unidades (${percentage}%)`;
                        }
                    }
                }
            }
        }
    });
}

// Gráfico de estado de vencimiento
function renderExpiryChart() {
    const ctx = document.getElementById('expiryChart').getContext('2d');
    
    // Destruir instancia anterior si existe
    if (chartInstances.expiryChart) {
        chartInstances.expiryChart.destroy();
    }
    
    const today = new Date();
    const nextWeek = new Date();
    nextWeek.setDate(today.getDate() + 7);
    const nextMonth = new Date();
    nextMonth.setDate(today.getDate() + 30);
    const nextThreeMonths = new Date();
    nextThreeMonths.setDate(today.getDate() + 90);
    
    let expired = 0, soon = 0, month = 0, threeMonths = 0, valid = 0;
    
    filteredProducts.forEach(product => {
        const expiryDate = new Date(product.expiry);
        const quantity = product.quantity;
        
        if (expiryDate < today) {
            expired += quantity;
        } else if (expiryDate <= nextWeek) {
            soon += quantity;
        } else if (expiryDate <= nextMonth) {
            month += quantity;
        } else if (expiryDate <= nextThreeMonths) {
            threeMonths += quantity;
        } else {
            valid += quantity;
        }
    });
    
    chartInstances.expiryChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ['Vencidos', '1-7 días', '8-30 días', '31-90 días', 'Más de 90 días'],
            datasets: [{
                label: 'Cantidad de productos',
                data: [expired, soon, month, threeMonths, valid],
                backgroundColor: [
                    '#ef4444', '#f59e0b', '#facc15', '#3b82f6', '#22c55e'
                ],
                borderWidth: 0,
                borderRadius: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        stepSize: 50
                    }
                }
            },
            plugins: {
                legend: {
                    display: false
                }
            }
        }
    });
}

// Gráfico de tendencia del inventario
function renderTrendChart() {
    const ctx = document.getElementById('trendChart').getContext('2d');
    
    // Destruir instancia anterior si existe
    if (chartInstances.trendChart) {
        chartInstances.trendChart.destroy();
    }
    
    // Calcular tendencia basada en los productos filtrados
    const totalQuantity = filteredProducts.reduce((sum, product) => sum + product.quantity, 0);
    const trendData = [...inventoryData.monthlyTrend];
    trendData[trendData.length - 1] = totalQuantity;
    
    chartInstances.trendChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: ['Ene', 'Feb', 'Mar', 'Abr', 'May'],
            datasets: [{
                label: 'Cantidad total de productos',
                data: trendData,
                borderColor: '#3b82f6',
                backgroundColor: 'rgba(59, 130, 246, 0.1)',
                borderWidth: 3,
                fill: true,
                tension: 0.4,
                pointBackgroundColor: '#3b82f6',
                pointBorderColor: '#fff',
                pointBorderWidth: 2,
                pointRadius: 5
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    beginAtZero: false,
                    min: Math.min(...trendData) - 10,
                    max: Math.max(...trendData) + 10
                }
            },
            plugins: {
                tooltip: {
                    mode: 'index',
                    intersect: false
                }
            }
        }
    });
}

// Renderizar la tabla de productos
function renderProductTable() {
    const tableBody = document.getElementById('productTable');
    tableBody.innerHTML = '';
    
    // Calcular productos para la página actual
    const startIndex = (currentPage - 1) * productsPerPage;
    const endIndex = startIndex + productsPerPage;
    const productsToShow = filteredProducts.slice(startIndex, endIndex);
    
    if (productsToShow.length === 0) {
        tableBody.innerHTML = `
            <tr>
                <td colspan="8" style="text-align: center; padding: 2rem; color: var(--gray);">
                    <i class="fas fa-inbox" style="font-size: 2rem; margin-bottom: 1rem; display: block;"></i>
                    No se encontraron productos que coincidan con los filtros
                </td>
            </tr>
        `;
    } else {
        productsToShow.forEach(product => {
            const expiryDate = new Date(product.expiry);
            const today = new Date();
            const timeDiff = expiryDate.getTime() - today.getTime();
            const daysDiff = Math.ceil(timeDiff / (1000 * 3600 * 24));
            
            let expiryClass = 'valid';
            let expiryText = formatDate(product.expiry);
            
            if (daysDiff < 0) {
                expiryClass = 'expired';
                expiryText = `${formatDate(product.expiry)} (Vencido)`;
            } else if (daysDiff <= 30) {
                expiryClass = 'warning';
                expiryText = `${formatDate(product.expiry)} (En ${daysDiff} días)`;
            }
            
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${product.name}</td>
                <td>${product.category}</td>
                <td>${product.quantity} ${product.unit}</td>
                <td class="${expiryClass}">${expiryText}</td>
                <td>${product.location}</td>
                <td>${product.supplier}</td>
                <td>$${product.price.toFixed(2)}</td>
                <td class="actions">
                    <button class="btn-action edit" data-id="${product.id}">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="btn-action delete" data-id="${product.id}">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            `;
            tableBody.appendChild(row);
        });
        
        // Agregar event listeners a los botones de acción
        tableBody.querySelectorAll('.btn-action.edit').forEach(btn => {
            btn.addEventListener('click', function() {
                const productId = parseInt(this.getAttribute('data-id'));
                editProduct(productId);
            });
        });
        
        tableBody.querySelectorAll('.btn-action.delete').forEach(btn => {
            btn.addEventListener('click', function() {
                const productId = parseInt(this.getAttribute('data-id'));
                deleteProduct(productId);
            });
        });
    }
    
    // Actualizar información de paginación
    updatePaginationInfo();
}

// Actualizar información de paginación
function updatePaginationInfo() {
    const totalPages = Math.ceil(filteredProducts.length / productsPerPage);
    document.getElementById('pageInfo').textContent = `Página ${currentPage} de ${totalPages}`;
    document.getElementById('tableInfo').textContent = 
        `Mostrando ${Math.min(filteredProducts.length, currentPage * productsPerPage)} de ${filteredProducts.length} productos`;
    
    // Habilitar/deshabilitar botones de paginación
    document.getElementById('prevPage').disabled = currentPage === 1;
    document.getElementById('nextPage').disabled = currentPage === totalPages || totalPages === 0;
}

// Ir a la página anterior
function goToPrevPage() {
    if (currentPage > 1) {
        currentPage--;
        renderProductTable();
    }
}

// Ir a la página siguiente
function goToNextPage() {
    const totalPages = Math.ceil(filteredProducts.length / productsPerPage);
    if (currentPage < totalPages) {
        currentPage++;
        renderProductTable();
    }
}

// Formatear fecha
function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('es-ES');
}

// Abrir modal para agregar/editar producto
function openProductModal(productId = null) {
    const modal = document.getElementById('productModal');
    const modalTitle = document.getElementById('modalTitle');
    const form = document.getElementById('productForm');
    
    if (productId) {
        // Modo edición
        modalTitle.textContent = 'Editar Producto';
        const product = inventoryData.products.find(p => p.id === productId);
        
        if (product) {
            document.getElementById('productId').value = product.id;
            document.getElementById('productName').value = product.name;
            document.getElementById('productCategory').value = product.category;
            document.getElementById('productQuantity').value = product.quantity;
            document.getElementById('productUnit').value = product.unit;
            document.getElementById('productExpiry').value = product.expiry;
            document.getElementById('productLocation').value = product.location;
            document.getElementById('productSupplier').value = product.supplier;
            document.getElementById('productPrice').value = product.price;
        }
    } else {
        // Modo agregar
        modalTitle.textContent = 'Agregar Producto';
        form.reset();
        document.getElementById('productId').value = '';
        
        // Establecer fecha mínima para vencimiento (hoy)
        const today = new Date().toISOString().split('T')[0];
        document.getElementById('productExpiry').min = today;
    }
    
    modal.style.display = 'flex';
}

// Cerrar modal de producto
function closeProductModal() {
    document.getElementById('productModal').style.display = 'none';
    document.getElementById('productForm').reset();
}

// Guardar producto (agregar o editar)
function saveProduct() {
    const form = document.getElementById('productForm');
    const productId = document.getElementById('productId').value;
    
    if (!form.checkValidity()) {
        form.reportValidity();
        return;
    }
    
    const productData = {
        name: document.getElementById('productName').value,
        category: document.getElementById('productCategory').value,
        quantity: parseInt(document.getElementById('productQuantity').value),
        unit: document.getElementById('productUnit').value,
        expiry: document.getElementById('productExpiry').value,
        location: document.getElementById('productLocation').value,
        supplier: document.getElementById('productSupplier').value,
        price: parseFloat(document.getElementById('productPrice').value)
    };
    
    if (productId) {
        // Editar producto existente
        const index = inventoryData.products.findIndex(p => p.id === parseInt(productId));
        if (index !== -1) {
            inventoryData.products[index] = { ...inventoryData.products[index], ...productData };
            showToast('Producto actualizado correctamente', 'success');
        }
    } else {
        // Agregar nuevo producto
        const newId = Math.max(...inventoryData.products.map(p => p.id), 0) + 1;
        inventoryData.products.push({ id: newId, ...productData });
        showToast('Producto agregado correctamente', 'success');
    }
    
    closeProductModal();
    filterProducts(); // Esto actualizará la tabla y los gráficos
}

// Editar producto
function editProduct(productId) {
    openProductModal(productId);
}

// Eliminar producto (mostrar confirmación)
function deleteProduct(productId) {
    productToDelete = productId;
    document.getElementById('confirmModal').style.display = 'flex';
}

// Confirmar eliminación
function confirmDelete() {
    if (productToDelete) {
        inventoryData.products = inventoryData.products.filter(p => p.id !== productToDelete);
        showToast('Producto eliminado correctamente', 'success');
        closeConfirmModal();
        filterProducts(); // Esto actualizará la tabla y los gráficos
    }
}

// Cerrar modal de confirmación
function closeConfirmModal() {
    document.getElementById('confirmModal').style.display = 'none';
    productToDelete = null;
}

// Mostrar notificación toast
function showToast(message, type = 'info') {
    // Eliminar toast existente si hay uno
    const existingToast = document.querySelector('.toast');
    if (existingToast) {
        existingToast.remove();
    }
    
    // Crear nuevo toast
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    document.body.appendChild(toast);
    
    // Eliminar toast después de la animación
    setTimeout(() => {
        if (toast.parentNode) {
            toast.parentNode.removeChild(toast);
        }
    }, 3000);
}

// Exportar datos (simulado)
function exportData() {
    showToast('Funcionalidad de exportación en desarrollo', 'info');
}

// Mostrar filtros avanzados (simulado)
function showAdvancedFilters() {
    showToast('Funcionalidad de filtros avanzados en desarrollo', 'info');
}