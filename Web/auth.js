// auth.js - VERSIÓN CON REDIRECCIÓN
window.onload = function() {
    // Verifica que Cognito esté cargado
    if (typeof AmazonCognitoIdentity === 'undefined') {
        console.error('AmazonCognitoIdentity no está cargado');
        alert('Error: Recarga la página. Si persiste, verifica la conexión.');
        return;
    }
    
    const poolData = {
        UserPoolId: 'us-east-2_LZM828aOx',
        ClientId: '6t1j1pprlaiuo86s2tp9p3g7ms'
    };

    const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);
    const loginForm = document.getElementById('loginForm');

    loginForm.addEventListener('submit', e => {
        e.preventDefault();

        const email = document.getElementById('email').value.trim();
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
                const idToken = result.getIdToken().getJwtToken();
                localStorage.setItem('idToken', idToken);
                
                // ✅ REDIRECCIÓN AUTOMÁTICA después de 2 segundos
                setTimeout(() => {
                    window.location.href = "https://bryamgr.github.io/PROYECTOINFRA.github.io/Dashboard/index.html";
                }, 500);
            },
            onFailure: err => {
                alert('Error: ' + (err.message || JSON.stringify(err)));
            }
        });
    });
    };