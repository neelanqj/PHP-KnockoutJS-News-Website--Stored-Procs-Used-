<?php
require('../apps/controller/database.class.php');
require('../apps/controller/userservice.class.php');

$pdo = Database::getConnection('write');

if ($_POST['ACTION'] == "getauthenticationcode") {
	$unformatted_json = $_POST['JSON'];
	$json = json_decode($unformatted_json);

	$userservice = new UserService($pdo,$json->email,'',$_POST['SESSION'],'','');
	
	$userservice->getEmailAuthentication();
	
} elseif ($_POST['ACTION'] == "resetpassword") {
	$unformatted_json = $_POST['JSON'];
	$json = json_decode($unformatted_json);

	$userservice = new UserService($pdo,$json->email,'',$_POST['SESSION'],'','');
	
	$userservice->changeForgottenPassword($json->newpassword, $json->reenternewpassword, $json->authenticationcode);
}
?>