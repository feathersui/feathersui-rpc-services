<?php
if (empty($_GET["name"])) {
	echo json_encode(array(
		"error" => "Missing name"
	));
}
else {
	echo json_encode(array(
		"message" => "Hi, " . $_GET["name"]
	));
}
?>