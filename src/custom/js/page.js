/* ************************************************************************************************************************ *
 *                                                                                                                          *
 *      Filename: page.js                                                                                           		*
 *      Description: This page contains the base models, collections, and viewmodels common functionality that will be used *
 *                   as the basis for the rest of the system. This was created to minimize code redundancy.                 *
 *      Dependancies:   Knockoutjs                                                                                          *
 *      Developer: Neelan Joachimpillai                                                                                     *
 *                                                                                                                          *
 *      Version control:                                                                                                    *
 *                              Neelan Joachimpillai        Dec 23, 2012        Created file.                               *
 *                                                                                                                          *
 * ************************************************************************************************************************ */

/* ************* Arranges knockout elements ************* */
var Core = {};

Core.Model = {};

Core.ViewModel = {};

/* ************* AJAX Loader Screen Code ************* */
$(document).ajaxStart(function() {
      $( "#loading" ).show();
});

$(document).ajaxStop(function() {
      $( "#loading" ).hide();
});

$(document).ready(function(){
	   $("#footer").load("html/footer.html").addClass($(this).text());
	   $("#bigLogo").load("html/logo.html").addClass($(this).text());
});

