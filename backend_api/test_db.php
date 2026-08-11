<?php
require_once "config.php";

$output = "Database Insertion Test\n";
$output .= "=======================\n\n";

try {
    // Attempt a dummy insert
    $series_stmt = $pdo->query("SELECT id FROM web_series LIMIT 1");
    $series_id = $series_stmt->fetchColumn();
    if (!$series_id) {
        $output .= "Error: No web series found in the database to test with.\n";
    } else {
        $output .= "Found web series ID: $series_id to test with.\n";
        $name = "Test Season " . rand(1, 99);
        $order = 9;
        
        $output .= "Executing INSERT INTO web_series_seasons (web_series_id, Session_Name, season_order, status) VALUES ($series_id, '$name', $order, 1)...\n";
        $stmt = $pdo->prepare("INSERT INTO web_series_seasons (web_series_id, Session_Name, season_order, status) VALUES (?, ?, ?, 1)");
        $success = $stmt->execute([$series_id, $name, $order]);
        
        if ($success) {
            $season_id = $pdo->lastInsertId();
            $output .= "Success! Inserted season ID: $season_id\n";
            // Clean up
            $pdo->prepare("DELETE FROM web_series_seasons WHERE id = ?")->execute([$season_id]);
            $output .= "Cleaned up test season ID: $season_id\n";
        } else {
            $output .= "Error: execute() returned false.\n";
        }
    }
} catch (Exception $e) {
    $output .= "Exception occurred: " . $e->getMessage() . "\n";
}

file_put_contents("db_info.txt", $output);
echo "Database insertion test completed! Results saved to db_info.txt";
?>
