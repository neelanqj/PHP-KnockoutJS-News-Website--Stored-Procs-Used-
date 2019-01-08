<?php session_start(); ?>
<!DOCTYPE html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>RhanthoS News - Whats happening online?</title>
<meta name="keywords" content="news, blog, entertainment, rhanthos">
<meta name="author" content="Rhanthos">
<meta charset="UTF-8">
<!-- SEO -->

<link rel="canonical" href="http://www.rhanthos.ca" />

<meta property="og:title" content="Online News Aggregator" />
<meta property="og:type" content="website" />
<meta property="og:url" content="http://www.rhanthos.ca" />
<meta property="og:image" content="http://www.rhanthos.ca/logo.ico" />
<meta property="og:site_name" content="Rhanthos News" />
<meta property="fb:admins" content="75408333052" />
<meta name="twitter:card" value="summary" />
<meta name="twitter:description" value="Rhanthos News - Bringing News To You" />

<meta name="description" content="The most interesting stories on the web.">
<meta property="og:description" content="The most interesting stories on the web." />
<!-- End SEO -->

<link rel="icon" type="image/ico" href="../../logo.ico"></link> 
<link rel="shortcut icon" href="../../logo.ico"></link>
    
    <!-- CSS File Library Includes -->
    <link rel="stylesheet" type="text/css" href="../../src/library/bootstrap/css/bootstrap.css"/>
    <link rel="stylesheet" type="text/css" href="../../src/library/bootstrap/css/bootstrap-responsive.css"/>    
    <link rel="stylesheet" type="text/css" href="../../src/custom/css/page.css"/>
    
    <!-- JavaScript Library Includes -->
    <script language="JavaScript" type="text/javascript" src='../../src/library/jquery/jquery-1.9.1.js'></script>
    <script language="JavaScript" type="text/javascript" src='../../src/library/modernizr/modernizr-2.5.3.min.js'></script>   
    <script language="JavaScript" type="text/javascript" src='../../src/library/jquery-cookie/jquery.cookie.js'></script>
    <script language="JavaScript" type="text/javascript" src='../../src/library/bootstrap/js/bootstrap.js'></script>
    <script language="JavaScript" type="text/javascript" src='../../src/library/jquery-getUrlParam/jquery.getUrlParam.js'></script>
    <script language="JavaScript" type="text/javascript" src='../../src/library/knockoutjs/knockout-2.2.1.js'></script>
    <script language="JavaScript" type="text/javascript" src='../../src/custom/js/knockout.bindings.js'></script>  
    
    <!-- Custom Script -->
    <script language="JavaScript" type="text/javascript" src='../../src/custom/js/apps/viewmodels/search.viewmodel.js' defer="defer"></script>  
   	<script language="JavaScript" type="text/javascript" src='../../src/custom/js/apps/page/search.page.js' defer="defer"></script>
	<script language="JavaScript" type="text/javascript" src='../../src/custom/js/page.js'></script>

</head>

<body>
	<?php include('headernav.inc.php'); ?>
    <div id="channels" class="row-fluid">
		<div class="span12 padsides">
			  <div class="span1">
					<br/><br/><br/>
					<a class="categories" id="cinema">
					<img class="select" data-bind="style: { opacity: category() =='cinema'?1: 0.4 }" src="../../src/custom/img/movies.jpg"><br/>
					Cinema</a>
			  </div>

			  <div class="span1">
					<br/><br/><br/>
					<a class="categories" id="worldnhistory">
					<img class="select" data-bind="style: { opacity: category() =='worldnhistory'?1: 0.4 }" src="../../src/custom/img/travel.jpg"><br/>
					World / History</a>
			  </div>
			  
			  <div class="span2">
					<br/><br/><br/>
					<a class="categories" id="society">
					<img class="select" data-bind="style: { opacity: category() =='society'?1: 0.4 }" src="../../src/custom/img/contraversy.jpg"><br/>
					Society</a>
			  </div>
			  
			  <div class="span4">
					<div class="row-fluid">
						<br/><br/><br/><br/>
						<a class="select" data-bind="style: { opacity: category() ==''?1: 0.4 }" href="/apps/view/search.view.php"><img src="../../src/custom/img/Logo.jpg" /></a>
					</div>
					<div class="row-fluid">
					    <br/><br/>
					</div>
					<div class="row-fluid">
						<b>Powered by you.</b><br/><br/><br/>
					</div>
			  </div>
			  
			  <div class="span2">
					<br/><br/><br/>
					<a class="categories" id="scintech">
					<img class="select" data-bind="style: { opacity: category() =='scintech'?1: 0.4 }" src="../../src/custom/img/technology.jpg"><br/>
					Science / Technology</a>
			  </div>
			  
			  <div class="span1">
					<br/><br/><br/>
					<a class="categories" id="body" >
					<img class="select" data-bind="style: { opacity: category() =='body'?1: 0.4 }" src="../../src/custom/img/fitness.jpg"><br/>
					Body</a>
			  </div>
			  
			  <div class="span1">
					<br/><br/><br/>
					<a class="categories" id="sexndating">
					<img class="select" data-bind="style: { opacity: category() =='sexndating'?1: 0.4 }" src="../../src/custom/img/bikini.jpg"><br/>
					Sex / Dating</a>
			  </div>
		
		</div>
	</div>
	
     <!-- pagination -->
     <div class="row-fluid">
     	<div class="span12 text-center">
            <div class="pagination">
              <ul>
                <li data-bind="attr: { 'class': (pagenum() == 1)?'disabled':'' }"><a data-bind="click: prevPage">Prev</a></li>
                <li data-bind="attr: { 'class': (pagenum() == totalpages() || totalpages() == 0)?'disabled':'' }"><a data-bind="click: nextPage">Next</a></li>
              </ul>
            </div>        
        </div>
     </div>
       
     <div class="row-fluid">
    	<div class="span12 text-center">
           <div class="pagination">
             <ul data-bind="template: { name: 'pagination-item',  foreach: ko.utils.range(1, totalpages()) }"></ul>
           </div>
		</div>
    </div>
    <!-- end pagination -->
    
    <div class="row-fluid">
        <div id="container" data-bind="visible: linkList().length > 0, template: { name: 'article-row',  foreach: linkList }">
        </div>
    </div>
    <div class="row-fluid">
    	<div id="loading" class="text-center" data-bind="scroll: linkList().length < 100, scrollOptions: { loadFunc: scrolled, offset: 10 }">  
            <img src="../../src/custom/img/mini-loading.gif"/>
        </div>
    </div>
    
    <div class="row-fluid" data-bind="visible: linkList().length == 0">
        <div class="span12 text-center"> No Articles<br/><br/><br/><br/> </div>
   </div>


    <div class="row-fluid">
        <div class="span12" id="footer"></div>
    </div>
    
    <!-- Templates -->
	<script type="text/html" id="article-row">	
			<div class="item">
				<div class="fluid-row">
					<div class="span12" data-bind="text: 'category: ' + category"></div>
				</div>

				<div class="fluid-row">
					<h3><a data-bind="text: title, attr: { href: (linktype == 1)? '/apps/view/link.view.php?id=' + id :'/apps/view/article.view.php?id=' + id }" target="_blank"></a></h3>
				</div>
				<div class="fluid-row">
					<img data-bind="attr: { src: pathname }" />
				</div>
				<div class="fluid-row fbottom">

					<a data-bind="attr: { href: '/apps/view/comments.view.php?id=' + id }, text: 'comments (' + numcomments + ') '"></a><br/>

					<a class="twitter_ico pull-left" data-bind="attr: { href: 'http://twitter.com/share?text=' + title +' @PEooT&url=http://rhanthos.ca/apps/view/link.view.php?id=' + id }"></a>
					<a class="facebook_ico pull-left "  data-bind="attr: { href: 'http://www.facebook.com/sharer.php?s=100&p[url]=http://rhanthos.ca/apps/view/link.view.php?id=' + id +'&p[images][0]=http://rhanthos.ca/src/custom/img/Logo.jpg&p[title]=' + title + ' @PEooT' }"></a>
					<a class="linkedin_ico pull-left" data-bind="attr: { href: 'http://www.linkedin.com/shareArticle?mini=true&url=http://rhanthos.ca/apps/view/link.view.php?id=' + id + '&title=' + title + ' @PEooT' }"></a><br/><br/>
					<span data-bind="text: createdate"></span>

				</div>
			</div>
    </script>
    
    <script type="text/html" id="pagination-item">
           <li data-bind="attr: { 'class': ($data == $root.pagenum())?'active':'' }">
		   		<a data-bind="text: $data, click: $root.setPage"></a>
		   </li>
    </script>

<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', 'UA-42820320-1', 'rhanthos.ca');
  ga('send', 'pageview');

</script>
</body>
</html>