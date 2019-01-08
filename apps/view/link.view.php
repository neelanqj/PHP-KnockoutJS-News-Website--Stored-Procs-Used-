<?php session_start();
require('../controller/database.class.php');
require('../controller/newsservice.class.php');

$pdo = Database::getConnection('read');

$newsservice = new NewsService($pdo,'','','','');

$newsservice->goToArticleAddress($_GET['id']);
?>