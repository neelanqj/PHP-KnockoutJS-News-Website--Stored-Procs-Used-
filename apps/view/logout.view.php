<?php
// Initialize the session.
// If you are using session_name("something"), don't forget it now!
session_start();

include_once '../controller/database.class.php';
include_once '../controller/userservice.class.php';

$pdo = Database::getConnection('write');

$email = isset($_SESSION['email'])?$_SESSION['email']:'';
$password = isset($_SESSION['password'])?$_SESSION['password']:'';
$passcode = isset($_SESSION['passcode'])?$_SESSION['passcode']:'';

$userService = new UserService($pdo, $email, $password, session_id(), $_SERVER['REMOTE_ADDR'], $passcode);
$userService->logout();

// Finally, destroy the session.
session_destroy();
session_start();
?>
<!DOCTYPE html>
<html>
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>Job Search</title>
    <link rel="icon" type="image/ico" href="../../favicon.ico"></link> 
    <link rel="shortcut icon" href="../../favicon.ico"></link>
    
    <!-- CSS File Library Includes -->
    <link rel="stylesheet" type="text/css" href="../../src/library/bootstrap/css/bootstrap.css"/>
    <link rel="stylesheet" type="text/css" href="../../src/library/bootstrap/css/bootstrap-responsive.css"/>
    
    <!-- JavaScript Library Includes -->
    <script language="JavaScript" type="text/javascript" src='../../src/library/jquery/jquery-1.9.1.js'></script>    
    <script language="JavaScript" type="text/javascript" src='../../src/library/jquery-cookie/jquery.cookie.js'></script>
    <script language="JavaScript" type="text/javascript" src='../../src/library/bootstrap/js/bootstrap.js'></script>
    <script language="JavaScript" type="text/javascript" src='../../src/library/jquery-getUrlParam/jquery.getUrlParam.js'></script>
        
    <!-- Custom CSS -->
    <link rel="stylesheet" type="text/css" href="../../src/custom/css/page.css">
    
</head>
<body>
<?php include("../view/headernav.inc.php"); ?>
        
        <div class="row-fluid">
              <div class="span12 text-center">    
              		<div class="row-fluid">
                    	<img src="../../src/custom/img/logo/Logo.png" />
                    </div>
                     <div id="message"></div>
                    <div class="row-fluid">
                		You have been signed out.<br/><br/>
            		</div>
              </div>
        </div>

        <div class="row-fluid">
            <div class="span8 offset4 text-center">
                	<div class="span6"><br/><br/><br/>
	                	Good Bye.
                    </div>            
            </div>
         </div>
     </div>

<?php include("../view/footer.inc.php"); ?>
	<script language="JavaScript" type="text/javascript">
        $("#message").text($(document).getUrlParam("message").replace(/%20/g," "));
    </script>

</body>
</html>
