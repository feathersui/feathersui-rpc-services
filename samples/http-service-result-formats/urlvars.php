<?php
if (empty($_GET["name"])) {
	echo "error=" . urlencode("Missing name");
}
else {
	echo "message=" . urlencode("Hi, " . $_GET["name"]);
}
?>