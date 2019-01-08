<?php
session_start();
include_once '../controller/database.class.php';
include_once '../controller/userservice.class.php';

$pdo = Database::getConnection('read');

// Generate a temp passcode
$_SESSION['passcode'] = substr(md5(rand()), 0, 100);
$userService = new UserService($pdo, $_POST['email'], $_POST['password'], session_id(), $_SERVER['REMOTE_ADDR'], $_SESSION['passcode']);
if ($userService->login()) {
	//echo 'Accessing Server<br/>';
	if($userService->checkCredentials()) {
		//echo 'Logged In<br/>';
		header('Location: mainall.view.php');
	}
	// do stuff
} 
	
echo 'Invalid Login, Password or Your Account Has Not Been Activated <a href="activate.view.php">(Click HERE To Activate)</a>.';

?>
