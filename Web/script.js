<<<<<<< HEAD
// Solo funcionalidades del login
document.addEventListener('DOMContentLoaded', function() {
    // Toggle para mostrar/ocultar contraseña
    const togglePassword = document.getElementById('togglePassword');
    const passwordInput = document.getElementById('password');
    
    if (togglePassword && passwordInput) {
        togglePassword.addEventListener('click', function() {
            const type = passwordInput.getAttribute('type') === 'password' ? 'text' : 'password';
            passwordInput.setAttribute('type', type);
            this.querySelector('i').classList.toggle('fa-eye');
            this.querySelector('i').classList.toggle('fa-eye-slash');
        });
        }

        // Validación básica del formulario
    const loginForm = document.getElementById('loginForm');
    
    if (loginForm) {
        loginForm.addEventListener('submit', function(e) {
            const email = document.getElementById('email').value.trim();
            const password = document.getElementById('password').value;
            
            // Validación básica (Cognito hará la validación real)
            if (!email || !password) {
                e.preventDefault();
                alert('Por favor completa todos los campos');
            }
        });
    }
});
=======
    // JS puramente de front: toggle de contraseña + validación mínima + UX del botón
    document.addEventListener("DOMContentLoaded", function () {
    const togglePassword = document.getElementById("togglePassword");
    const passwordInput  = document.getElementById("password");
    const loginForm      = document.getElementById("loginForm");
    const btn            = loginForm?.querySelector(".btn");
    const emailInput     = document.getElementById("email");

    // Toggle mostrar/ocultar contraseña
    if (togglePassword && passwordInput) {
        togglePassword.addEventListener("click", function () {
        const type = passwordInput.getAttribute("type") === "password" ? "text" : "password";
        passwordInput.setAttribute("type", type);
        const icon = this.querySelector("i");
        icon?.classList.toggle("fa-eye");
        icon?.classList.toggle("fa-eye-slash");
        });
    }

    // Pequeña UX de "cargando" del botón
    function setBusy(isBusy) {
        if (!btn) return;
        if (isBusy) {
        btn.classList.add("loading");
        btn.disabled = true;
        } else {
        btn.classList.remove("loading");
        btn.disabled = false;
        }
    }

    // Validación básica (sin backend)
    if (loginForm) {
        loginForm.addEventListener("submit", function (e) {
        const email = emailInput?.value.trim() || "";
        const password = passwordInput?.value || "";

        if (!email || !password) {
            e.preventDefault();
            alert("Por favor completa todos los campos");
            return;
        }

        if (password.length < 6) {
            e.preventDefault();
            alert("La contraseña debe tener al menos 6 caracteres");
            return;
        }

        // Solo demo front: prevenimos submit real y simulamos éxito
        e.preventDefault();
        setBusy(true);

        setTimeout(() => {
            setBusy(false);
            // Aquí podrías redirigir a un HTML estático del dashboard si lo tienes:
            // window.location.href = "./Dashboard/index.html";
            alert("Inicio de sesión (solo front). Integra tu backend cuando esté listo.");
        }, 900);
        });
    }
    });
>>>>>>> 2271e8b (feat: Cambios respecto a Cognito)
