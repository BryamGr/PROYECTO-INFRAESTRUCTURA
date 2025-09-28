// auth.js - VERSIÓN CORREGIDA
window.onload = function() {
    // Verifica que Cognito esté cargado
    if (typeof AmazonCognitoIdentity === 'undefined') {
        console.error('AmazonCognitoIdentity no está cargado');
        alert('Error: Recarga la página. Si persiste, verifica la conexión.');
        return;
    }
    
    const poolData = {
        UserPoolId: 'us-east-2_tMrodja4K',
        ClientId: '1a73vcf7enqc5ibrup6lat3r1d'
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
                document.getElementById('successModal').style.display = 'block';
            },
            onFailure: err => {
                alert('Error: ' + (err.message || JSON.stringify(err)));
            }
        });
    });

    // Cerrar modal de éxito
    const modalClose = document.getElementById('modalClose');
    if (modalClose) {
        modalClose.addEventListener('click', function() {
            document.getElementById('successModal').style.display = 'none';
        });
    }
};