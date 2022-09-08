<response>
<?php if (empty($_GET["name"])): ?>
	<error>Missing name</error>
<?php else: ?>
	<message>Hi, <?php echo htmlspecialchars($_GET["name"]) ?></message>
<?php endif; ?>
</response>