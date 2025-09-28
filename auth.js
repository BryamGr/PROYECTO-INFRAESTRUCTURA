document.addEventListener('DOMContentLoaded', () => {
    const poolData = {
        UserPoolId: 'us-east-2_tMrodja4K',
        ClientId: '7g6tuctmqp12j2v16ul8crfktm'
    };

    // Mover esta línea aquí
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
});
