 <?
        $connect=mysql_connect("localhost","juggerjo_root","nbuser") or die("Unable to Connect");
        mysql_select_db("juggerjo_jnews") or die("Could not open the db");
        $showtablequery="SHOW TABLES FROM juggerjo_jnews";
        $query_result=mysql_query($showtablequery);
        while($showtablerow = mysql_fetch_array($query_result))
        {
        echo $showtablerow[0]." ";
        } 
        ?>