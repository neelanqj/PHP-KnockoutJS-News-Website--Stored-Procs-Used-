<?php 
	session_start() ;
	if(!isset($_COOKIE["passcode"])) {
		echo '<meta http-equiv="expired cookie" content="logout.view.php?msg=expired">';
	}
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Control Panel</title>
<link rel="icon" type="image/ico" href="../../logo.ico"></link> 
<link rel="shortcut icon" href="../../logo.ico"></link>
    
    <!-- CSS File Library Includes -->
    <link rel="stylesheet" type="text/css" href="../../src/library/bootstrap/css/bootstrap.css"/>
    <link rel="stylesheet" type="text/css" href="../../src/library/bootstrap/css/bootstrap-responsive.css"/>   
    
    <!-- JavaScript Library Includes -->
    <script language="JavaScript" type="text/javascript" src='../../src/library/jquery/jquery-1.9.1.js'></script>
    <script language="JavaScript" type="text/javascript" src='../../src/library/jquery-cookie/jquery.cookie.js'></script>
    <script language="JavaScript" type="text/javascript" src='../../src/library/bootstrap/js/bootstrap.js'></script>
    <script language="JavaScript" type="text/javascript" src='../../src/library/knockoutjs/knockout-2.2.1.js'></script>  
    
    <!-- Custom CSS -->
    <link rel="stylesheet" type="text/css" href="../../src/custom/css/page.css">
    
    <!-- JavaScript Includes -->
    <script language="JavaScript" type="text/javascript" src='../../src/custom/js/page.js'></script> 
    <script language="JavaScript" type="text/javascript" src='../../src/custom/js/apps/viewmodels/usercp.viewmodel.js' defer="defer"></script>
    <script language="JavaScript" type="text/javascript" src='../../src/custom/js/apps/page/usercp.page.js' defer="defer"></script>
    
</head>

<body>
		<?php 
		if (isset($_SESSION['user_id']) && !empty($_SESSION['user_id'])) { 
		include("../view/headernav.inc.php"); ?>
        
        <div class="row-fluid">
          <div class="span12 text-center">    
                <div id="bigLogo" class="row-fluid">
                </div>
                <div class="row-fluid">
                    <h5>Control Panel</h5><br/><br/>
                </div>
          </div>
        </div>
        <div class="row-fluid">
            <div class="span8 offset4 text-center">
                    <div class="span6">
                        <div class="row-fluid">
                            <div class="span12">
                                <hr/>User Settings<hr/>
                            </div>
                        </div>
                        <div class="row-fluid">                      	
                            <div class="span6">
                                <a href="accountsettings.view.php"><i class="icon-user"></i> Update Information</a>
                            </div>
                            <div class="span6">
                                <a href="changepassword.view.php"><i class="icon-user"></i> Change Password</a>
                            </div>
                        </div>                                           
                                                     
                    </div>              
            </div>
        </div>
        <div class="row-fluid">
            <div class="span8 offset4 text-center">
                <div class="span6">
                    <div class="row-fluid">
                        <div class="span12">
                            <hr/>General<hr/>
                        </div>
                    </div>
                    <div class="row-fluid">                      	
                        <div class="span6">
                            <a href="submitarticle.view.php"><i class="icon-envelope"></i> Submit Article</a>
                        </div>
                        <div class="span6">
                            <a href="submitlink.view.php"><i class="icon-envelope"></i> Submit Link</a>
                        </div>
                    </div>    
                    <!--
                    <div class="row-fluid">                      	
                        <div class="span6">
                            <a href="submissionlist.view.php"><i class="icon-user"></i> Submission List</a>
                        </div>
                        <div class="span6">
                            <a href="mycomments.view.php"><i class="icon-user"></i> My Comments</a>
                        </div>
                    </div>                 
                    -->                                          
                </div>              
            </div>
        </div>         
        <div class="row-fluid" data-bind="visible: cinemaPanel()">
            <div class="span8 offset4 text-center">
                <div class="span6">
                    <div class="row-fluid">
                        <div class="span12">
                            <hr/>Super Panel<hr/>
                        </div>
                    </div>
                    <div class="row-fluid">                      	
                        <div class="span6">
                            <a href="directpublisharticle.view.php"><i class="icon-envelope"></i> Direct Publish Article</a>
                        </div>
                        <div class="span6">
                        	<a href="directpublishlink.view.php"><i class="icon-envelope"></i> Direct Publish Link</a>
                        </div>
                    </div> 
                                        
                    <div class="row-fluid">
                        <div class="span6">
                        	<a href="unreviewedarticles.view.php"><i class="icon-eye-open"></i> Review Articles</a>
                        </div>                    	
                        <div class="span6">
                        </div>
                    </div>                          
                                                             
                </div>              
            </div>
        </div>     
   		<div id="footer"></div>
    <?php 
	}?>

</body>
</html>