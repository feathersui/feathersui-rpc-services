<?php
if (empty($_GET["name"])) {
	http_response_code(400);
}
else {
	echo "Hi, " . $_GET["name"];
}
?>