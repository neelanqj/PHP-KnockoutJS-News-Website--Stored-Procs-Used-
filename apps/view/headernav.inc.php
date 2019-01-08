<!-- <img id="loading" class="centerimage hide" src="../../src/custom/img/animate/loading2.gif" /> -->
<div class="navbar navbar-fixed-top navbar-inverse">
  <div class="navbar-inner">
    <ul class="nav">
      <li><a href="#"> </a></li>
      <li>
      	<a class="brand" href="#"> 
      		<img src="../../src/custom/img/Logo-mini.png" width="25" height="25" /> 
        </a>
      </li>
      <li><a href="/apps/view/search.view.php">Home</a></li>
      <li><a href="/apps/view/search.view.php">Recent</a></li>
      <li class="divider-vertical"></li>
      <?php
      if (isset($_SESSION['user_id']) && !empty($_SESSION['user_id'])) { 
						echo "</li><li class='active'><a href='/apps/view/usercp.view.php'>Control Panel</a></li><li class='divider-vertical'></li><li><a href='/apps/view/submitarticle.view.php'>Submit Article</a></li><li><a href='/apps/view/submitlink.view.php'>Submit Link</a></li><li class='divider-vertical'></li>";
					}
                    if (!isset($_SESSION['user_id'])) { 
                    ?>
                    
                    <li class="dropdown">
                      <a class="dropdown-toggle" role="button" data-toggle="dropdown">
                        Login
                        <b class="caret"></b>
                      </a>   
                      <!-- Drop down element -->
                       <ul class="dropdown-menu logo darkness" role="menu" aria-labelledby="dLabel">
                            <li>                      
                                <!-- Login Element -->
                                <div class="loginform">
                                    <form action="/apps/view/login.view.php" method="post" class="form-horizontal">
                                      <div class="control-group">
                                        <label class="control-label" for="email">Email</label>
                                        <div class="controls">
                                          <input type="text" name="email" id="email" placeholder="Email">
                                        </div>
                                      </div>
                                      <div class="control-group">
                                        <label class="control-label" for="password">Password</label>
                                        <div class="controls">
                                          <input type="password" name="password" id="password" placeholder="Password">
                                        </div>
                                      </div>
                                      <div class="control-group">
                                        <div class="controls">
                                          <button type="submit" class="btn">Sign in</button>
                                        </div>
                                      </div>
                                      <div class="pull-right">
                                        <a class="glow" href="/apps/view/forgotpassword.view.php">Forgot Password?</a> &nbsp;&nbsp;
                                        <a class="glow"  href="/apps/view/activate.view.php">Verify Account</a>
                                      </div>
                                    </form>
                                </div>
                                <!-- End Of Login Element -->
                            </li>
                        </ul>
                        <!-- End of drop down element -->
                    </li>
                    <li><a href="/apps/view/signup.view.php">Join</a></li>
                <?php } else { 
                    echo '<li><a href="/apps/view/logout.view.php">Logout</a></li>';
                 } ?>          
                    <li><a href="/apps/view/about.view.php">About</a></li>
                    <li><a href="/apps/view/contact.view.php">Contact us</a></li>     
                </ul>
    </ul>
    <ul class="nav pull-right">
        <li class="divider-vertical"></li>
        <form action="/apps/view/search.view.php" method="get"  class="navbar-search">
          <input name="f" type="hidden" value="<?php echo isset($_GET['f'])?$_GET['f']:''; ?>" />
          <input name="s" type="text" class="search-query" placeholder="Search">
        </form>
        <li class="divider-vertical"></li>
    </ul>
  </div>
</div>
<iframe src="/apps/view/tracker.php" style="width:0;height:0;border:0; border:none;"></iframe>