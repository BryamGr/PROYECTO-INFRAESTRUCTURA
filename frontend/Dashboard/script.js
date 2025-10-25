    document.addEventListener('DOMContentLoaded', async () => {
    // Inicialización simple (sin sesión obligatoria)
    await initDashboard();
    setupEventListeners();
    });

    // =========================
    // URLs de la API (ajústalas al desplegar)
    const INVENTORY_API_BASE = 'http://localhost:3000/api';
    const REPORTS_API_BASE   = 'http://localhost:3001/api';
    const AUTH_API_BASE      = 'http://localhost:3002/api'; // Tu API propia de usuarios (sin Cognito)
    // =========================

    // Variables globales
    let currentPage = 1;
    const productsPerPage = 10;
    let currentSort = { column: 'name', direction: 'asc' };
    let filteredProducts = [];
    let productToDelete = null;
    let chartInstances = {};
    let inventoryData = { products: [] };

    // =========================
    // Dashboard
    async function initDashboard() {
    await loadProductsFromAPI();
    updateSummaryCards();
    await renderCharts();
    renderProductTable();
    setupSorting();

    // Restricción mínima a fecha
    const today = new Date().toISOString().split('T')[0];
    const expiryInput = document.getElementById('productExpiry');
    if (expiryInput) expiryInput.min = today;
    }

    function setupEventListeners() {
    // Productos
    document.getElementById('addProduct').addEventListener('click', openProductModal);
    document.getElementById('search').addEventListener('input', filterProducts);
    document.getElementById('filterCategory').addEventListener('change', filterProducts);
    document.getElementById('filterExpiry').addEventListener('change', filterProducts);
    document.getElementById('cancelBtn').addEventListener('click', closeProductModal);
    document.getElementById('saveProduct').addEventListener('click', saveProduct);
    document.getElementById('cancelDelete').addEventListener('click', closeConfirmModal);
    document.getElementById('confirmDelete').addEventListener('click', confirmDelete);
    document.getElementById('prevPage').addEventListener('click', goToPrevPage);
    document.getElementById('nextPage').addEventListener('click', goToNextPage);
    document.getElementById('exportBtn').addEventListener('click', exportData);
    document.getElementById('filterBtn').addEventListener('click', showAdvancedFilters);

    // Usuarios
    const registerUserBtn = document.getElementById('registerUser');
    const cancelUserBtn   = document.getElementById('cancelUser');
    const createUserBtn   = document.getElementById('createUser');
    if (registerUserBtn) registerUserBtn.addEventListener('click', openUserModal);
    if (cancelUserBtn)   cancelUserBtn.addEventListener('click', closeUserModal);
    if (createUserBtn)   createUserBtn.addEventListener('click', createUser);

    // Cerrar por X de cualquier modal
    document.querySelectorAll('.close-modal').forEach(btn => {
        btn.addEventListener('click', function() {
        closeProductModal();
        closeConfirmModal();
        closeUserModal();
        });
    });

    // Cerrar clickeando fuera
    window.addEventListener('click', function(event) {
        ['productModal','confirmModal','userModal'].forEach(id => {
        const m = document.getElementById(id);
        if (event.target === m) m.style.display = 'none';
        });
    });
    }

    // =========================
    // Inventario (API)
    async function loadProductsFromAPI() {
    try {
        const response = await fetch(`${INVENTORY_API_BASE}/productos`);
        const result = await response.json();

        if (result.success) {
        inventoryData.products = result.data.map(product => ({
            id: product.id,
            name: product.nombre,
            category: product.categoria,
            quantity: product.stock,
            unit: 'unidades',
            expiry: product.fecha_caducidad,
            location: 'Almacén A',
            supplier: 'Proveedor General',
            price: parseFloat(product.precio)
        }));
        filteredProducts = [...inventoryData.products];
        } else {
        throw new Error(result.error || 'Respuesta inválida');
        }
    } catch (error) {
        console.warn('No se pudo consultar API de inventario. Usando lista vacía:', error.message);
        inventoryData.products = [];
        filteredProducts = [];
    }
    }

    // =========================
    function setupSorting() {
    document.querySelectorAll('th[data-sort]').forEach(th => {
        th.addEventListener('click', function() {
        const column = this.getAttribute('data-sort');
        sortTable(column);
        });
    });
    }

    function sortTable(column) {
    document.querySelectorAll('th[data-sort]').forEach(th => th.classList.remove('sorted-asc','sorted-desc'));

    if (currentSort.column === column) {
        currentSort.direction = currentSort.direction === 'asc' ? 'desc' : 'asc';
    } else {
        currentSort.column = column;
        currentSort.direction = 'asc';
    }

    filteredProducts.sort((a, b) => {
        let aValue = a[column];
        let bValue = b[column];
        if (column === 'expiry') { aValue = new Date(aValue); bValue = new Date(bValue); }
        if (column === 'quantity') { aValue = a.quantity; bValue = b.quantity; }
        if (column === 'price') { aValue = a.price; bValue = b.price; }
        if (aValue < bValue) return currentSort.direction === 'asc' ? -1 : 1;
        if (aValue > bValue) return currentSort.direction === 'asc' ?  1 : -1;
        return 0;
    });

    const currentTh = document.querySelector(`th[data-sort="${column}"]`);
    currentTh.classList.add(currentSort.direction === 'asc' ? 'sorted-asc' : 'sorted-desc');
    currentPage = 1;
    renderProductTable();
    }

    // =========================
    // Filtro + cards + charts
    function filterProducts() {
    const searchTerm = document.getElementById('search').value.toLowerCase();
    const categoryFilter = document.getElementById('filterCategory').value;
    const expiryFilter = document.getElementById('filterExpiry').value;

    filteredProducts = inventoryData.products.filter(product => {
        const matchesSearch = product.name.toLowerCase().includes(searchTerm) ||
                            product.category.toLowerCase().includes(searchTerm);
        const matchesCategory = categoryFilter === 'all' || product.category === categoryFilter;

        const expiryDate = new Date(product.expiry);
        const today = new Date();
        const daysDiff = Math.ceil((expiryDate - today) / (1000 * 60 * 60 * 24));

        let matchesExpiry = true;
        if (expiryFilter === 'expired') matchesExpiry = daysDiff < 0;
        else if (expiryFilter === 'soon') matchesExpiry = daysDiff >= 0 && daysDiff <= 30;
        else if (expiryFilter === 'valid') matchesExpiry = daysDiff > 30;

        return matchesSearch && matchesCategory && matchesExpiry;
    });

    currentPage = 1;
    renderProductTable();
    updateSummaryCards();
    renderCharts();
    }

    function updateSummaryCards() {
    const totalProducts = filteredProducts.length;
    const totalQuantity = filteredProducts.reduce((s, p) => s + p.quantity, 0);
    const inventoryValue = filteredProducts.reduce((s, p) => s + (p.price * p.quantity), 0);

    const today = new Date();
    const nextMonth = new Date(); nextMonth.setDate(today.getDate() + 30);
    const nextExpire = filteredProducts.filter(p => {
        const expiryDate = new Date(p.expiry);
        return expiryDate > today && expiryDate <= nextMonth;
    }).length;

    document.getElementById('totalProducts').textContent = totalProducts;
    document.getElementById('totalQuantity').textContent = totalQuantity;
    document.getElementById('inventoryValue').textContent = `$${inventoryValue.toFixed(2)}`;
    document.getElementById('nextExpire').textContent = nextExpire;
    }

    async function renderCharts() {
    await renderCategoryChart();
    renderExpiryChart();
    await renderTrendChart();
    }

    async function renderCategoryChart() {
    const ctx = document.getElementById('categoryChart').getContext('2d');
    if (chartInstances.categoryChart) chartInstances.categoryChart.destroy();

    try {
        const response = await fetch(`${REPORTS_API_BASE}/reportes/metricas`);
        const result = await response.json();

        if (result.success) {
        const items = result.data.distribucionCategorias;
        const labels = items.map(i => i.categoria);
        const data = items.map(i => i.cantidad);

        chartInstances.categoryChart = new Chart(ctx, {
            type: 'doughnut',
            data: {
            labels,
            datasets: [{
                data,
                backgroundColor: ['#facc15','#3b82f6','#a855f7','#22c55e','#ef4444','#8b5cf6','#06b6d4','#84cc16','#f97316','#ec4899'],
                borderWidth:2,
                borderColor:'#fff'
            }]
            },
            options: { responsive:true, maintainAspectRatio:false, plugins:{ legend:{ position:'bottom', labels:{ padding:20, usePointStyle:true } } } }
        });
        return;
        }
    } catch (_) {}

    // fallback sin datos
    chartInstances.categoryChart = new Chart(ctx, {
        type:'doughnut',
        data:{ labels:['Sin datos'], datasets:[{ data:[1], backgroundColor:['#e5e7eb'] }] }
    });
    }

    function renderExpiryChart() {
    const ctx = document.getElementById('expiryChart').getContext('2d');
    if (chartInstances.expiryChart) chartInstances.expiryChart.destroy();

    const today = new Date();
    const nextWeek = new Date(); nextWeek.setDate(today.getDate() + 7);
    const nextMonth = new Date(); nextMonth.setDate(today.getDate() + 30);
    const nextThreeMonths = new Date(); nextThreeMonths.setDate(today.getDate() + 90);

    let expired = 0, soon = 0, month = 0, threeMonths = 0, valid = 0;

    filteredProducts.forEach(p => {
        const d = new Date(p.expiry);
        const q = p.quantity;
        if (d < today) expired += q;
        else if (d <= nextWeek) soon += q;
        else if (d <= nextMonth) month += q;
        else if (d <= nextThreeMonths) threeMonths += q;
        else valid += q;
    });

    chartInstances.expiryChart = new Chart(ctx, {
        type: 'bar',
        data: {
        labels: ['Vencidos','1-7 días','8-30 días','31-90 días','Más de 90 días'],
        datasets: [{
            label: 'Cantidad de productos',
            data: [expired,soon,month,threeMonths,valid],
            backgroundColor: ['#ef4444','#f59e0b','#facc15','#3b82f6','#22c55e'],
            borderWidth:0,
            borderRadius:4
        }]
        },
        options: { responsive:true, maintainAspectRatio:false, scales:{ y:{ beginAtZero:true } }, plugins:{ legend:{ display:false } } }
    });
    }

    async function renderTrendChart() {
    const ctx = document.getElementById('trendChart').getContext('2d');
    if (chartInstances.trendChart) chartInstances.trendChart.destroy();

    let trendData;
    try {
        const r = await fetch(`${REPORTS_API_BASE}/reportes/tendencias`);
        const result = await r.json();
        if (result.success && result.data.length > 0) {
        trendData = result.data.map(i => i.cantidad || i.valor);
        }
    } catch (_) {}

    if (!trendData) {
        const total = filteredProducts.reduce((s,p)=>s+p.quantity,0);
        trendData = [total*0.8, total*0.9, total*0.95, total, total*1.1];
    }

    chartInstances.trendChart = new Chart(ctx, {
        type: 'line',
        data: {
        labels:['Ene','Feb','Mar','Abr','May','Jun'],
        datasets:[{
            label:'Cantidad total de productos',
            data:trendData,
            borderColor:'#3b82f6',
            backgroundColor:'rgba(59,130,246,0.1)',
            borderWidth:3,
            fill:true,
            tension:0.4,
            pointBackgroundColor:'#3b82f6',
            pointBorderColor:'#fff',
            pointBorderWidth:2,
            pointRadius:5
        }]
        },
        options: {
        responsive:true,
        maintainAspectRatio:false,
        scales:{ y:{ beginAtZero:false, min: Math.min(...trendData)*0.9, max: Math.max(...trendData)*1.1 } }
        }
    });
    }

    // =========================
    // Tabla
    function renderProductTable() {
    const tableBody = document.getElementById('productTable');
    tableBody.innerHTML = '';

    const startIndex = (currentPage - 1) * productsPerPage;
    const endIndex = startIndex + productsPerPage;
    const productsToShow = filteredProducts.slice(startIndex, endIndex);

    if (productsToShow.length === 0) {
        tableBody.innerHTML = `
        <tr>
            <td colspan="8" style="text-align:center;padding:2rem;color:var(--gray);">
            <i class="fas fa-inbox" style="font-size:2rem;margin-bottom:1rem;display:block;"></i>
            No se encontraron productos que coincidan con los filtros
            </td>
        </tr>`;
    } else {
        productsToShow.forEach(product => {
        const expiryDate = new Date(product.expiry);
        const today = new Date();
        const timeDiff = expiryDate.getTime() - today.getTime();
        const daysDiff = Math.ceil(timeDiff / (1000 * 3600 * 24));

        let expiryClass = 'valid';
        let expiryText = formatDate(product.expiry);
        if (daysDiff < 0) { expiryClass = 'expired'; expiryText = `${formatDate(product.expiry)} (Vencido)`; }
        else if (daysDiff <= 30) { expiryClass = 'warning'; expiryText = `${formatDate(product.expiry)} (En ${daysDiff} días)`; }

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
            </td>`;
        tableBody.appendChild(row);
        });

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

    updatePaginationInfo();
    }

    function updatePaginationInfo() {
    const totalPages = Math.ceil(filteredProducts.length / productsPerPage) || 1;
    document.getElementById('pageInfo').textContent = `Página ${currentPage} de ${totalPages}`;
    document.getElementById('tableInfo').textContent =
        `Mostrando ${Math.min(filteredProducts.length, currentPage * productsPerPage)} de ${filteredProducts.length} productos`;

    document.getElementById('prevPage').disabled = currentPage === 1;
    document.getElementById('nextPage').disabled = currentPage >= totalPages || totalPages === 0;
    }

    function goToPrevPage() { if (currentPage > 1) { currentPage--; renderProductTable(); } }
    function goToNextPage() {
    const totalPages = Math.ceil(filteredProducts.length / productsPerPage) || 1;
    if (currentPage < totalPages) { currentPage++; renderProductTable(); }
    }

    // =========================
    // Utilidades
    function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('es-ES');
    }
    function showToast(message, type = 'info') {
    const existingToast = document.querySelector('.toast');
    if (existingToast) existingToast.remove();
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    document.body.appendChild(toast);
    setTimeout(() => { if (toast.parentNode) toast.parentNode.removeChild(toast); }, 3000);
    }

    // Password temporal local (no depende de políticas externas)
    function generateTempPassword() {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const nums  = '23456789';
    const syms  = '!@#$%^&*()-_=+';
    const pick = (s) => s[Math.floor(Math.random()*s.length)];
    let pwd = pick(upper)+pick(lower)+pick(nums)+pick(syms);
    const all = upper+lower+nums+syms;
    while (pwd.length < 12) pwd += pick(all);
    return pwd.split('').sort(()=>Math.random()-0.5).join('');
    }
    async function copyToClipboard(text) {
    try { await navigator.clipboard.writeText(text); } catch {}
    }

    // =========================
    // Modales Producto
    function openProductModal(productId = null) {
    const modal = document.getElementById('productModal');
    const modalTitle = document.getElementById('modalTitle');

    if (productId) {
        modalTitle.textContent = 'Editar Producto';
        const product = inventoryData.products.find(p => p.id === productId);
        if (product) {
        document.getElementById('productId').value       = product.id;
        document.getElementById('productName').value     = product.name;
        document.getElementById('productCategory').value = product.category;
        document.getElementById('productQuantity').value = product.quantity;
        document.getElementById('productUnit').value     = product.unit;
        document.getElementById('productExpiry').value   = product.expiry;
        document.getElementById('productLocation').value = product.location;
        document.getElementById('productSupplier').value = product.supplier;
        document.getElementById('productPrice').value    = product.price;
        }
    } else {
        modalTitle.textContent = 'Agregar Producto';
        document.getElementById('productForm').reset();
        document.getElementById('productId').value = '';
        const today = new Date().toISOString().split('T')[0];
        document.getElementById('productExpiry').min = today;
    }
    modal.style.display = 'flex';
    }
    function closeProductModal() {
    const modal = document.getElementById('productModal');
    if (modal) modal.style.display = 'none';
    const form = document.getElementById('productForm');
    if (form) form.reset();
    }

    // Guardar producto (API)
    async function saveProduct() {
    const form = document.getElementById('productForm');
    const productId = document.getElementById('productId').value;
    if (!form.checkValidity()) { form.reportValidity(); return; }

    const productData = {
        nombre: document.getElementById('productName').value,
        categoria: document.getElementById('productCategory').value,
        precio: parseFloat(document.getElementById('productPrice').value),
        stock: parseInt(document.getElementById('productQuantity').value),
        fecha_caducidad: document.getElementById('productExpiry').value
    };

    try {
        let response;
        if (productId) {
        response = await fetch(`${INVENTORY_API_BASE}/productos/${productId}`, {
            method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(productData)
        });
        } else {
        response = await fetch(`${INVENTORY_API_BASE}/productos`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(productData)
        });
        }
        const result = await response.json();

        if (result.success) {
        showToast(productId ? 'Producto actualizado correctamente' : 'Producto agregado correctamente', 'success');
        closeProductModal();
        await loadProductsFromAPI();
        renderProductTable(); updateSummaryCards(); renderCharts();
        } else { throw new Error(result.error || 'Operación no exitosa'); }
    } catch (error) {
        console.error('Error guardando producto:', error);
        showToast('Error al guardar el producto: ' + error.message, 'error');
    }
    }

    function editProduct(productId) { openProductModal(productId); }
    function deleteProduct(productId) {
    productToDelete = productId;
    document.getElementById('confirmModal').style.display = 'flex';
    }
    async function confirmDelete() {
    if (!productToDelete) return;
    try {
        const response = await fetch(`${INVENTORY_API_BASE}/productos/${productToDelete}`, { method: 'DELETE' });
        const result = await response.json();
        if (result.success) {
        showToast('Producto eliminado correctamente', 'success');
        closeConfirmModal();
        await loadProductsFromAPI();
        renderProductTable(); updateSummaryCards(); renderCharts();
        } else { throw new Error(result.error || 'No se pudo eliminar'); }
    } catch (error) {
        console.error('Error eliminando producto:', error);
        showToast('Error al eliminar el producto: ' + error.message, 'error');
    }
    }
    function closeConfirmModal() {
    const modal = document.getElementById('confirmModal');
    if (modal) modal.style.display = 'none';
    productToDelete = null;
    }

    // Exportar datos
    async function exportData() {
    try {
        const response = await fetch(`${INVENTORY_API_BASE}/productos`);
        const result = await response.json();
        if (!result.success) throw new Error(result.error || 'Respuesta inválida');

        const dataStr = JSON.stringify(result.data, null, 2);
        const dataBlob = new Blob([dataStr], { type: 'application/json' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(dataBlob);
        link.download = 'inventario.json';
        link.click();
        showToast('Datos exportados correctamente', 'success');
    } catch (error) {
        console.error('Error exportando datos:', error);
        showToast('Error al exportar datos', 'error');
    }
    }

    function showAdvancedFilters() {
    showToast('Funcionalidad de filtros avanzados en desarrollo', 'info');
    }

    // =========================
    // Usuarios (modal + llamada a tu backend propio)
    function openUserModal() {
    const modal = document.getElementById('userModal');
    const form  = document.getElementById('userForm');
    if (form) form.reset();
    if (modal) modal.style.display = 'flex';
    }
    function closeUserModal() {
    const modal = document.getElementById('userModal');
    if (modal) modal.style.display = 'none';
    }

    async function createUser() {
    const name  = document.getElementById('userName').value.trim();
    const email = document.getElementById('userEmail').value.trim();
    const role  = document.getElementById('userRole').value; // 'admin' | 'empleado'
    const phone = document.getElementById('userPhone').value.trim();

    if (!name || !email || !role) {
        showToast('Completa los campos obligatorios.', 'error');
        return;
    }

    // Contraseña temporal generada en el front (por comodidad de pruebas)
    const tempPassword = generateTempPassword();

    const payload = {
        nombre: name,
        email,
        telefono: phone || null,
        rol: role,                // <-- rol propio (no grupos Cognito)
        passwordTemporal: tempPassword
    };

    try {
        const resp = await fetch(`${AUTH_API_BASE}/usuarios`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
        });
        const result = await resp.json().catch(() => ({}));

        if (!resp.ok) throw new Error(result.error || 'No se pudo crear el usuario');

        closeUserModal();
        showToast('Usuario creado', 'success');

        // Copia la contraseña temporal para que pruebes inmediatamente
        await copyToClipboard(tempPassword);
        alert(`Usuario creado:\n\nEmail: ${email}\nContraseña temporal: ${tempPassword}\n\n(La contraseña se copió al portapapeles)`);
    } catch (err) {
        console.error('Error creando usuario:', err);
        showToast('Error al crear usuario: ' + err.message, 'error');
    }
    }
