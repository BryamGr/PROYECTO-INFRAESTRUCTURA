// Helpers UI
function setBusy(btnEl, busy) {
  if (!btnEl) return;
  if (busy) { btnEl.classList.add("loading"); btnEl.disabled = true; }
  else { btnEl.classList.remove("loading"); btnEl.disabled = false; }
}

function showError(el, msg) {
  if (!el) return;
  el.textContent = msg || "";
  if (msg) el.style.color = "#e53935";
}

function storage(remember) {
  return remember ? window.localStorage : window.sessionStorage;
}

function saveSession(token, user, remember) {
  const s = storage(remember);
  s.setItem("token", token);
  s.setItem("user", JSON.stringify(user || {}));
}

function readAPIBase() {
  const base = (window.API_BASE || "").replace(/\/+$/, "");
  if (!base) console.warn("API_BASE no configurado. Reemplaza '__API_BASE__' en index.html");
  return base;
}

document.addEventListener("DOMContentLoaded", () => {
  // Elementos comunes
  const loginForm = document.getElementById("loginForm");
  const registerForm = document.getElementById("registerForm");
  const viewTitle = document.getElementById("viewTitle");
  const viewSubtitle = document.getElementById("viewSubtitle");
  const goToRegister = document.getElementById("goToRegister");
  const goToLogin = document.getElementById("goToLogin");

  // ----- Toggle vistas (login <-> registro)
  function showLogin() {
    loginForm.style.display = "";
    registerForm.style.display = "none";
    viewTitle.textContent = "Iniciar Sesión";
    viewSubtitle.textContent = "Ingresa tus credenciales para acceder al sistema";
  }
  function showRegister() {
    loginForm.style.display = "none";
    registerForm.style.display = "";
    viewTitle.textContent = "Crear cuenta";
    viewSubtitle.textContent = "Completa tus datos para registrarte";
  }
  goToRegister?.addEventListener("click", (e) => { e.preventDefault(); showRegister(); });
  goToLogin?.addEventListener("click", (e) => { e.preventDefault(); showLogin(); });

  // ----- Toggle de visibilidad de contraseña
  const togglePassword = document.getElementById("togglePassword");
  const passwordInput = document.getElementById("password");
  togglePassword?.addEventListener("click", function () {
    const type = passwordInput.getAttribute("type") === "password" ? "text" : "password";
    passwordInput.setAttribute("type", type);
    const icon = this.querySelector("i");
    icon?.classList.toggle("fa-eye");
    icon?.classList.toggle("fa-eye-slash");
  });
  // Toggles en registro
  document.querySelectorAll(".toggle-password[data-target]").forEach((el) => {
    el.addEventListener("click", function () {
      const target = document.getElementById(this.dataset.target);
      if (!target) return;
      const type = target.getAttribute("type") === "password" ? "text" : "password";
      target.setAttribute("type", type);
      const icon = this.querySelector("i");
      icon?.classList.toggle("fa-eye");
      icon?.classList.toggle("fa-eye-slash");
    });
  });

  // ====== LOGIN ======
  loginForm?.addEventListener("submit", async (e) => {
    e.preventDefault();

    const btn = document.getElementById("loginBtn");
    const dni = (document.getElementById("dni")?.value || "").trim();
    const pwd = document.getElementById("password")?.value || "";
    const remember = document.getElementById("remember")?.checked || false;

    showError(document.getElementById("dniError"), "");
    showError(document.getElementById("passwordError"), "");
    showError(document.getElementById("loginMessage"), "");

    if (!dni) { showError(document.getElementById("dniError"), "Ingresa tu DNI"); return; }
    if (!pwd || pwd.length < 6) { showError(document.getElementById("passwordError"), "Contraseña inválida"); return; }

    setBusy(btn, true);
    try {
      const API = readAPIBase();
      const resp = await fetch(`${API}/api/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ dni, password: pwd })
      });
      const data = await resp.json();

      if (!resp.ok || data.success === false) {
        const msg = data?.error || "No se pudo iniciar sesión";
        showError(document.getElementById("loginMessage"), msg);
        return;
      }

      saveSession(data.token, data.data, remember);

      // Redirigir al Dashboard (CloudFront: /)
      const dest = (window.POST_LOGIN_REDIRECT || "/");
      window.location.href = dest;
    } catch (err) {
      console.error("Login error", err);
      showError(document.getElementById("loginMessage"), "Error de conexión con el servidor");
    } finally {
      setBusy(btn, false);
    }
  });

  // ====== REGISTRO ======
  registerForm?.addEventListener("submit", async (e) => {
    e.preventDefault();

    const btn = document.getElementById("registerBtn");
    const nombre = (document.getElementById("reg_nombre")?.value || "").trim();
    const apellido_paterno = (document.getElementById("reg_apellido")?.value || "").trim();
    const dni = (document.getElementById("reg_dni")?.value || "").trim();
    const edad = Number(document.getElementById("reg_edad")?.value || 0);
    const pass = document.getElementById("reg_password")?.value || "";
    const pass2 = document.getElementById("reg_password2")?.value || "";
    const regError = document.getElementById("regError");
    const regMsg = document.getElementById("registerMessage");

    showError(regError, ""); showError(regMsg, "");

    if (!nombre || !apellido_paterno || !dni || !edad || !pass) {
      showError(regError, "Completa todos los campos"); return;
    }
    if (edad < 18) { showError(regError, "Debes ser mayor de edad"); return; }
    if (pass.length < 6) { showError(regError, "La contraseña debe tener al menos 6 caracteres"); return; }
    if (pass !== pass2) { showError(regError, "Las contraseñas no coinciden"); return; }

    setBusy(btn, true);
    try {
      const API = readAPIBase();
      const resp = await fetch(`${API}/api/auth/register`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ nombre, apellido_paterno, dni, edad, password: pass })
      });
      const data = await resp.json();

      if (!resp.ok || data.success === false) {
        const msg = data?.error || "No se pudo registrar el usuario";
        showError(regError, msg);
        return;
      }

      // Ya devuelve token; guardamos y redirigimos
      saveSession(data.token, data.data, true);
      window.location.href = (window.POST_LOGIN_REDIRECT || "/");
    } catch (err) {
      console.error("Register error", err);
      showError(regError, "Error de conexión con el servidor");
    } finally {
      setBusy(btn, false);
    }
  });
});

