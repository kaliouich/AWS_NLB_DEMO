#!/bin/bash

# Update system
yum update -y

# Install dependencies
yum install -y httpd mysql

# Install PHP
amazon-linux-extras enable php8.0
yum clean metadata
yum install -y php php-mysqli

# Create simple API endpoint
cat > /var/www/html/api.php << 'EOF'
<?php
header('Content-Type: application/json');

$db_host = getenv('DB_HOST');
$db_name = getenv('DB_NAME');
$db_user = getenv('DB_USERNAME');
$db_pass = getenv('DB_PASSWORD');

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create table if not exists
    $pdo->exec("CREATE TABLE IF NOT EXISTS requests (
        id INT AUTO_INCREMENT PRIMARY KEY,
        endpoint VARCHAR(255),
        client_ip VARCHAR(45),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
    
    // Log this request
    $stmt = $pdo->prepare("INSERT INTO requests (endpoint, client_ip) VALUES (?, ?)");
    $stmt->execute([$_SERVER['REQUEST_URI'], $_SERVER['REMOTE_ADDR']]);
    
    // Get request count
    $countStmt = $pdo->query("SELECT COUNT(*) as count FROM requests");
    $count = $countStmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    echo json_encode([
        'status' => 'success',
        'message' => 'API is working!',
        'database_connection' => 'successful',
        'total_requests' => $count,
        'server_time' => date('Y-m-d H:i:s'),
        'client_ip' => $_SERVER['REMOTE_ADDR']
    ]);
    
} catch (PDOException $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Database connection failed',
        'error' => $e->getMessage()
    ]);
}
?>
EOF

# Create health check endpoint
cat > /var/www/html/health.php << 'EOF'
<?php
header('Content-Type: application/json');

$db_host = getenv('DB_HOST');
$db_name = getenv('DB_NAME');
$db_user = getenv('DB_USERNAME');
$db_pass = getenv('DB_PASSWORD');

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo json_encode([
        'status' => 'healthy',
        'database' => 'connected',
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    
} catch (PDOException $e) {
    http_response_code(503);
    echo json_encode([
        'status' => 'unhealthy',
        'database' => 'disconnected',
        'error' => $e->getMessage()
    ]);
}
?>
EOF

# Create index page
cat > /var/www/html/index.html << 'EOF'
<html>
<head>
    <title>API Server</title>
</head>
<body>
    <h1>API Server is Running</h1>
    <p>Endpoints available:</p>
    <ul>
        <li><a href="/api.php">/api.php</a> - Main API endpoint</li>
        <li><a href="/health.php">/health.php</a> - Health check</li>
    </ul>
</body>
</html>
EOF

# Set environment variables
echo "DB_HOST=${db_host}" >> /etc/environment
echo "DB_NAME=${db_name}" >> /etc/environment
echo "DB_USERNAME=${db_username}" >> /etc/environment
echo "DB_PASSWORD=${db_password}" >> /etc/environment

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Set proper permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

echo "API server setup complete!"