<?php
require_once "config.php";

$input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
$action = $_GET['action'] ?? $_POST['action'] ?? $input['action'] ?? '';

// Ensure user_db has required columns (idempotent migrations)
try {
    $hasPic = $pdo->query("SHOW COLUMNS FROM user_db LIKE 'profile_pic'")->fetch();
    if (!$hasPic) {
        $pdo->exec("ALTER TABLE user_db ADD COLUMN profile_pic TEXT NOT NULL");
    }
    $hasDeviceId = $pdo->query("SHOW COLUMNS FROM user_db LIKE 'device_id'")->fetch();
    if (!$hasDeviceId) {
        $pdo->exec("ALTER TABLE user_db ADD COLUMN device_id VARCHAR(255) DEFAULT ''");
    }
    $hasDeviceName = $pdo->query("SHOW COLUMNS FROM user_db LIKE 'device_name'")->fetch();
    if (!$hasDeviceName) {
        $pdo->exec("ALTER TABLE user_db ADD COLUMN device_name VARCHAR(255) DEFAULT ''");
    }
} catch (Exception $e) {}

if ($action === 'register') {
    $name = trim($input['name'] ?? '');
    $email = strtolower(trim($input['email'] ?? ''));
    $password = trim($input['password'] ?? '');
    $device_id = trim($input['device_id'] ?? '');
    $device_name = trim($input['device_name'] ?? '');

    if (empty($name) || empty($email) || empty($password)) {
        json_response(false, [], "Please fill in all fields (Name, Email, Password)");
    }

    if (strlen($password) < 4) {
        json_response(false, [], "Password must be at least 4 characters long");
    }

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        json_response(false, [], "Please enter a valid email address (e.g. name@domain.com)");
    }

    try {
        $stmt = $pdo->prepare("SELECT id FROM user_db WHERE LOWER(TRIM(email)) = ?");
        $stmt->execute([$email]);
        if ($stmt->fetch()) {
            json_response(false, [], "This email is already registered. Please log in.");
        }

        $hashed_pass = md5($password);

        // Fetch all actual table columns in user_db to dynamically build the INSERT
        // This prevents MySQL Strict Mode (STRICT_TRANS_TABLES) errors on custom or missing columns.
        $colsStmt = $pdo->query("SHOW COLUMNS FROM user_db");
        $allCols = $colsStmt ? $colsStmt->fetchAll(PDO::FETCH_COLUMN) : [];

        $defaultMap = [
            'name' => $name,
            'email' => $email,
            'password' => $hashed_pass,
            'role' => 0,
            'active_subscription' => 'Free',
            'subscription_type' => 0,
            'time' => 0,
            'amount' => 0,
            'subscription_start' => '1970-01-01',
            'subscription_exp' => '1970-01-01',
            'profile_pic' => '',
            'device_id' => $device_id,
            'device_name' => $device_name,
            'status' => 1,
            'type' => 0,
            'custom_tag' => '',
            'app_version' => '1.0.0',
            'verified' => 1,
        ];

        $insertCols = [];
        $insertVals = [];
        $placeholders = [];

        foreach ($defaultMap as $col => $val) {
            if (empty($allCols) || in_array($col, $allCols)) {
                $insertCols[] = "`$col`";
                $placeholders[] = "?";
                $insertVals[] = $val;
            }
        }

        if (!empty($insertCols)) {
            $sql = "INSERT INTO user_db (" . implode(', ', $insertCols) . ") VALUES (" . implode(', ', $placeholders) . ")";
            $stmt = $pdo->prepare($sql);
            $stmt->execute($insertVals);
        } else {
            $stmt = $pdo->prepare("INSERT INTO user_db (name, email, password, role, active_subscription) VALUES (?, ?, ?, 0, 'Free')");
            $stmt->execute([$name, $email, $hashed_pass]);
        }

        $user_id = $pdo->lastInsertId();

        $stmt = $pdo->prepare("SELECT id, name, email, role, profile_pic, active_subscription, subscription_type, time, amount, subscription_exp, device_id, device_name FROM user_db WHERE id = ?");
        $stmt->execute([$user_id]);
        $userRow = $stmt->fetch();

        json_response(true, ["user" => $userRow], "Registration successful");
    } catch (Exception $e) {
        json_response(false, [], "Registration error: " . $e->getMessage());
    }
}

if ($action === 'login') {
    $email = strtolower(trim($input['email'] ?? ''));
    $password = trim($input['password'] ?? '');
    $device_id = trim($input['device_id'] ?? '');
    $device_name = trim($input['device_name'] ?? '');
    $force_login = intval($input['force_login'] ?? 0);

    if (empty($email) || empty($password)) {
        json_response(false, [], "Email and password required");
    }

    $hashed_pass = md5($password);
    $stmt = $pdo->prepare("SELECT id, name, email, role, profile_pic, active_subscription, subscription_type, time, amount, subscription_exp, device_id, device_name FROM user_db WHERE LOWER(TRIM(email)) = ? AND (password = ? OR password = ?)");
    $stmt->execute([$email, $hashed_pass, $password]);
    $user = $stmt->fetch();

    if (!$user) {
        json_response(false, [], "Invalid email or password");
    }

    // Check device concurrent login constraint
    if (!empty($device_id)) {
        $db_device_id = $user['device_id'] ?? '';
        $db_device_name = $user['device_name'] ?? '';
        if (!empty($db_device_id) && $db_device_id !== $device_id && $force_login !== 1) {
            json_response(false, [
                "device_conflict" => true,
                "old_device_name" => $db_device_name ?: "Another device"
            ], "Device limit reached");
        }
        // Save current device info as active session
        $pdo->prepare("UPDATE user_db SET device_id = ?, device_name = ? WHERE id = ?")
            ->execute([$device_id, $device_name, $user['id']]);
        
        $user['device_id'] = $device_id;
        $user['device_name'] = $device_name;
    }

    json_response(true, ["user" => $user], "Login successful");
}

if ($action === 'get_user') {
    $user_id = intval($input['user_id'] ?? $_GET['user_id'] ?? $input['id'] ?? 0);
    $device_id = trim($input['device_id'] ?? $_GET['device_id'] ?? '');

    if ($user_id <= 0) json_response(false, [], "User ID required");
    $stmt = $pdo->prepare("SELECT id, name, email, role, profile_pic, active_subscription, subscription_type, time, amount, subscription_exp, device_id, device_name FROM user_db WHERE id = ?");
    $stmt->execute([$user_id]);
    $user = $stmt->fetch();
    if (!$user) json_response(false, [], "User not found");

    // If device_id is passed, check if it matches the active DB session
    if (!empty($device_id) && !empty($user['device_id']) && $user['device_id'] !== $device_id) {
        json_response(false, ["logged_out" => true], "Logged out because another device logged in");
    }

    json_response(true, ["user" => $user], "User fetched");
}

if ($action === 'update_profile') {
    $user_id = intval($input['user_id'] ?? 0);
    $name = trim($input['name'] ?? '');
    $profile_pic = trim($input['profile_pic'] ?? '');
    $current_password = trim($input['current_password'] ?? '');
    $new_password = trim($input['new_password'] ?? '');

    if ($user_id <= 0 || empty($name)) {
        json_response(false, [], "Invalid parameters");
    }

    // If changing password, verify the current password first
    if (!empty($new_password)) {
        $stmt = $pdo->prepare("SELECT password FROM user_db WHERE id = ?");
        $stmt->execute([$user_id]);
        $row = $stmt->fetch();
        if (!$row || (md5($current_password) !== $row['password'] && $current_password !== $row['password'])) {
            json_response(false, [], "Current password is incorrect");
        }
        $pdo->prepare("UPDATE user_db SET name = ?, profile_pic = ?, password = ? WHERE id = ?")
            ->execute([$name, $profile_pic, md5($new_password), $user_id]);
    } else {
        $pdo->prepare("UPDATE user_db SET name = ?, profile_pic = ? WHERE id = ?")
            ->execute([$name, $profile_pic, $user_id]);
    }

    $stmt = $pdo->prepare("SELECT id, name, email, role, profile_pic, active_subscription, subscription_type, time, amount, subscription_exp, device_id, device_name FROM user_db WHERE id = ?");
    $stmt->execute([$user_id]);
    json_response(true, ["user" => $stmt->fetch()], "Profile updated successfully");
}

json_response(false, [], "Invalid action");
?>
