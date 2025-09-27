// Esperar a que el DOM esté completamente cargado
document.addEventListener('DOMContentLoaded', function() {
    // Elementos del DOM
    const loginForm = document.getElementById('loginForm');
    const emailInput = document.getElementById('email');
    const passwordInput = document.getElementById('password');
    const togglePassword = document.getElementById('togglePassword');
    const rememberCheckbox = document.getElementById('remember');
    const submitButton = document.querySelector('.btn');
    const successModal = document.getElementById('successModal');
    const modalClose = document.getElementById('modalClose');
    const welcomeMessage = document.getElementById('welcomeMessage');
    const signupLink = document.getElementById('signupLink');
    const forgotLink = document.querySelector('.forgot');
    
    // Cargar datos guardados si existe la opción "Recordar mis datos"
    if (localStorage.getItem('rememberMe') === 'true') {
        const savedEmail = localStorage.getItem('savedEmail');
        if (savedEmail) {
            emailInput.value = savedEmail;
            rememberCheckbox.checked = true;
        }
    }
    
    // Validación en tiempo real para el campo de email
    emailInput.addEventListener('input', function() {
        validateEmail();
    });
    
    // Validación en tiempo real para el campo de contraseña
    passwordInput.addEventListener('input', function() {
        validatePassword();
    });
    
    // Mostrar/ocultar contraseña
    togglePassword.addEventListener('click', function() {
        const type = passwordInput.getAttribute('type') === 'password' ? 'text' : 'password';
        passwordInput.setAttribute('type', type);
        
        // Cambiar icono
        const icon = togglePassword.querySelector('i');
        if (type === 'password') {
            icon.classList.remove('fa-eye-slash');
            icon.classList.add('fa-eye');
        } else {
            icon.classList.remove('fa-eye');
            icon.classList.add('fa-eye-slash');
        }
    });
    
    // Envío del formulario
    loginForm.addEventListener('submit', function(e) {
        e.preventDefault();
        
        // Validar campos antes de enviar
        const isEmailValid = validateEmail();
        const isPasswordValid = validatePassword();
        
        if (isEmailValid && isPasswordValid) {
            // Simular proceso de login
            simulateLogin();
        } else {
            // Mostrar mensaje de error general
            showError('Por favor, corrige los errores antes de continuar.');
        }
    });
    
    // Cerrar modal
    modalClose.addEventListener('click', function() {
        successModal.style.display = 'none';
        // Aquí podrías redirigir a la página principal
        // window.location.href = 'dashboard.html';
    });
    
    // Cerrar modal al hacer clic fuera del contenido
    window.addEventListener('click', function(e) {
        if (e.target === successModal) {
            successModal.style.display = 'none';
        }
    });
    
    // Enlace de solicitud de acceso
    signupLink.addEventListener('click', function(e) {
        e.preventDefault();
        alert('Para solicitar acceso al sistema, contacta al departamento de Recursos Humanos.');
    });
    
    // Enlace de olvidé contraseña
    forgotLink.addEventListener('click', function(e) {
        e.preventDefault();
        alert('Para recuperar tu contraseña, contacta al departamento de Sistemas.');
    });
    
    // Funciones de validación
    function validateEmail() {
        const email = emailInput.value.trim();
        const emailError = document.getElementById('emailError');
        let isValid = true;
        
        if (email === '') {
            emailError.textContent = 'El correo electrónico es obligatorio.';
            isValid = false;
        } else if (!isValidEmail(email)) {
            emailError.textContent = 'Por favor, ingresa un correo electrónico válido.';
            isValid = false;
        } else {
            emailError.textContent = '';
        }
        
        updateInputStatus(emailInput, isValid);
        return isValid;
    }
    
    function validatePassword() {
        const password = passwordInput.value;
        const passwordError = document.getElementById('passwordError');
        let isValid = true;
        
        if (password === '') {
            passwordError.textContent = 'La contraseña es obligatoria.';
            isValid = false;
        } else if (password.length < 6) {
            passwordError.textContent = 'La contraseña debe tener al menos 6 caracteres.';
            isValid = false;
        } else {
            passwordError.textContent = '';
        }
        
        updateInputStatus(passwordInput, isValid);
        return isValid;
    }
    
    function isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
    
    function updateInputStatus(input, isValid) {
        const statusIcon = input.parentNode.querySelector('.input-status');
        
        if (isValid && input.value.trim() !== '') {
            statusIcon.innerHTML = '<i class="fas fa-check"></i>';
            statusIcon.style.color = 'var(--success-color)';
        } else if (!isValid && input.value.trim() !== '') {
            statusIcon.innerHTML = '<i class="fas fa-times"></i>';
            statusIcon.style.color = 'var(--error-color)';
        } else {
            statusIcon.innerHTML = '';
        }
    }
    
    function showError(message) {
        // Crear elemento de error temporal
        const errorDiv = document.createElement('div');
        errorDiv.className = 'error-message global-error';
        errorDiv.textContent = message;
        errorDiv.style.cssText = `
            background: var(--error-color);
            color: white;
            padding: 10px;
            border-radius: var(--border-radius);
            margin-bottom: 20px;
            text-align: center;
            animation: fadeIn 0.3s ease;
        `;
        
        // Insertar antes del formulario
        loginForm.insertBefore(errorDiv, loginForm.firstChild);
        
        // Eliminar después de 5 segundos
        setTimeout(() => {
            if (errorDiv.parentNode) {
                errorDiv.parentNode.removeChild(errorDiv);
            }
        }, 5000);
    }
    
    function simulateLogin() {
        // Mostrar estado de carga
        submitButton.classList.add('loading');
        submitButton.disabled = true;
        
        // Simular llamada a API (2 segundos)
        setTimeout(() => {
            // Ocultar estado de carga
            submitButton.classList.remove('loading');
            submitButton.disabled = false;
            
            // Guardar datos si la opción está marcada
            if (rememberCheckbox.checked) {
                localStorage.setItem('rememberMe', 'true');
                localStorage.setItem('savedEmail', emailInput.value.trim());
            } else {
                localStorage.removeItem('rememberMe');
                localStorage.removeItem('savedEmail');
            }
            
            // Mostrar mensaje de éxito
            const email = emailInput.value.trim();
            const username = email.split('@')[0];
            welcomeMessage.textContent = `¡Bienvenido/a, ${username}! Has accedido al sistema de Productos Envasados.`;
            
            // Mostrar modal
            successModal.style.display = 'flex';
            
            // Limpiar formulario (excepto si está marcado recordar)
            if (!rememberCheckbox.checked) {
                loginForm.reset();
            }
            
        }, 2000);
    }
    
    // Agregar estilos CSS para la animación de fadeIn
    const style = document.createElement('style');
    style.textContent = `
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-10px); }
            to { opacity: 1; transform: translateY(0); }
        }
    `;
    document.head.appendChild(style);
});