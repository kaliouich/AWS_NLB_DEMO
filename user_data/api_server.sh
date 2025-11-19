#!/bin/bash

# Set up logging
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting user-data script at $(date)"

# Update system
yum update -y

# Install web server and PHP
yum install -y httpd php

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Configure Apache to handle PHP files
cat > /etc/httpd/conf.d/php.conf << 'EOF'
<FilesMatch \.php$>
    SetHandler application/x-httpd-php
</FilesMatch>
DirectoryIndex index.php index.html
EOF

# Create index.php instead of index.html
cat > /var/www/html/index.php << 'EOF'
<html>
<head><title>API Server</title></head>
<body>
    <h1>API Server is Running!</h1>
    <p>Instance ID: <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/instance-id'); ?></p>
    <p>Server Time: <?php echo date('Y-m-d H:i:s'); ?></p>
    <p>Private IP: <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/local-ipv4'); ?></p>
    
    <h2>Available Endpoints:</h2>
    <ul>
        <li><a href="/health.php">Health Check</a></li>
        <li><a href="/api.php">API Endpoint</a></li>
        <li><a href="/test.php">Test Page</a></li>
    </ul>
    
    <h2>Server Info:</h2>
    <pre>
<?php
echo "User: " . exec('whoami') . "\n";
echo "PHP Version: " . phpversion() . "\n";
echo "Server Software: " . $_SERVER['SERVER_SOFTWARE'] . "\n";
?>
    </pre>
</body>
</html>
EOF

# Create health check endpoint
cat > /var/www/html/health.php << 'EOF'
<?php
header('Content-Type: application/json');

$response = [
    'status' => 'healthy',
    'service' => 'web_server',
    'timestamp' => date('Y-m-d H:i:s'),
    'instance_id' => file_get_contents('http://169.254.169.254/latest/meta-data/instance-id'),
    'server_ip' => file_get_contents('http://169.254.169.254/latest/meta-data/local-ipv4'),
    'php_version' => phpversion()
];

echo json_encode($response, JSON_PRETTY_PRINT);
?>
EOF

# Create API endpoint
cat > /var/www/html/api.php << 'EOF'
<?php
header('Content-Type: application/json');

$response = [
    'status' => 'success',
    'message' => 'Welcome to API Server',
    'instance_id' => file_get_contents('http://169.254.169.254/latest/meta-data/instance-id'),
    'server_time' => date('Y-m-d H:i:s'),
    'client_ip' => $_SERVER['REMOTE_ADDR'],
    'request_method' => $_SERVER['REQUEST_METHOD'],
    'server_software' => $_SERVER['SERVER_SOFTWARE']
];

echo json_encode($response, JSON_PRETTY_PRINT);
?>
EOF

# Create test page
cat > /var/www/html/test.php << 'EOF'
<?php
echo "<h1>Test Page</h1>";
echo "<p>PHP is working!</p>";
echo "<p>Server Time: " . date('Y-m-d H:i:s') . "</p>";
echo "<p>Instance ID: " . file_get_contents('http://169.254.169.254/latest/meta-data/instance-id') . "</p>";
echo "<p>Private IP: " . file_get_contents('http://169.254.169.254/latest/meta-data/local-ipv4') . "</p>";

// Test database connection if credentials are available
$db_host = '${db_host}';
if (!empty($db_host)) {
    echo "<h2>Database Information:</h2>";
    echo "<p>DB Host: " . $db_host . "</p>";
    echo "<p>DB Name: ${db_name}</p>";
    echo "<p>DB User: ${db_username}</p>";
    
    // Simple connection test
    $test_cmd = "mysql -h ${db_host} -u ${db_username} -p'${db_password}' -e 'SELECT 1' 2>&1";
    $output = shell_exec($test_cmd);
    if (strpos($output, 'ERROR') === false) {
        echo "<p style='color: green;'>Database Connection: SUCCESS</p>";
    } else {
        echo "<p style='color: red;'>Database Connection: FAILED</p>";
        echo "<pre>Error: " . htmlspecialchars($output) . "</pre>";
    }
}

// Show PHP info
echo "<h2>PHP Info:</h2>";
echo "<p>PHP Version: " . phpversion() . "</p>";
echo "<p>Server: " . $_SERVER['SERVER_SOFTWARE'] . "</p>";
?>
EOF

# Create a simple text health check
echo "OK" > /var/www/html/health.txt

# Set proper permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Restart Apache to apply PHP configuration
systemctl restart httpd

# Test that web server is running and PHP is working
echo "Testing web server..."
if curl -s http://localhost/health.txt > /dev/null; then
    echo "SUCCESS: Web server is running on port 80"
else
    echo "ERROR: Web server failed to start"
    exit 1
fi

# Test PHP execution
echo "Testing PHP execution..."
PHP_TEST=$(curl -s http://localhost/index.php | grep "API Server is Running" || echo "PHP_FAILED")
if [ "$PHP_TEST" != "PHP_FAILED" ]; then
    echo "SUCCESS: PHP is executing properly"
else
    echo "ERROR: PHP is not executing"
    # Check Apache error logs
    tail -20 /var/log/httpd/error_log || echo "Could not read error log"
fi

# Install MySQL client for database testing
yum install -y mysql

echo "User-data script completed at $(date)"
echo "Web server and PHP setup complete!"