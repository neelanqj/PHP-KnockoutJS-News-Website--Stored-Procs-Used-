<?php
session_start();
include_once '../controller/database.class.php';
include_once '../controller/userservice.class.php';

$pdo = Database::getConnection('read');

$userService = new UserService($pdo, 'fightthepower', 'fightthepower', session_id(), $_SERVER['REMOTE_ADDR'],'fightthepower');

$userService->trackEm();

?>
