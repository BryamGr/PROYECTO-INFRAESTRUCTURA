// === Configura con tus datos reales ===
const poolData = {
  UserPoolId: 'us-east-2_tMrodja4K', // <-- tu User Pool ID
  ClientId:   '7g6tuctmqp12j2v16ul8crfktm' // <-- tu App client id
};
const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

// Capturamos el submit del formulario existente
document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('loginForm');

    loginForm.addEventListener('submit', e => {
    e.preventDefault();

    const email    = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;

    const authDetails = new AmazonCognitoIdentity.AuthenticationDetails({
        Username: email,
        Password: password
    });

    const userData = {
        Username: email,
        Pool: userPool
    };

    const cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);

    cognitoUser.authenticateUser(authDetails, {
        onSuccess: result => {
        // Guarda el token para tus peticiones a la API
        const idToken = result.getIdToken().getJwtToken();
        localStorage.setItem('idToken', idToken);

        // Aquí puedes mostrar tu modal de éxito o redirigir
        document.getElementById('successModal').style.display = 'block';
        console.log('Login OK', idToken);
        },
        onFailure: err => {
        alert('Error: ' + (err.message || JSON.stringify(err)));
        }
    });
    });
});
