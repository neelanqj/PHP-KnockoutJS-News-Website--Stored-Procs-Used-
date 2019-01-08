-- phpMyAdmin SQL Dump
-- version 4.8.3
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jan 08, 2019 at 03:50 PM
-- Server version: 5.6.41-cll-lve
-- PHP Version: 7.2.7

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `juggerjo_jnews`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`juggerjo`@`localhost` PROCEDURE `NS_ARTICLE` (IN `USERID` BIGINT, IN `PASSCODE` VARCHAR(500), IN `SESSIONID` VARCHAR(50), IN `IPADDRESS` VARCHAR(16), IN `ACTION` VARCHAR(200), IN `TITLE` VARCHAR(200), IN `CATEGORY` VARCHAR(200), IN `LINK` VARCHAR(500), IN `ARTICLE` LONGTEXT, IN `ID` BIGINT)  NS_ARTICLE: BEGIN
	
	
	IF ACTION = 'DISPLAYARTICLE' THEN
		SELECT AL.title
				, A.body
				, DATE_FORMAT(AL.createdate, '%b %d, %Y (%r)') AS createdate
				, UPPER(CONCAT(UI.firstName, ' ', UI.lastName)) AS author
		FROM articlelinks AL LEFT JOIN article A
		ON AL.articleid = A.articleid
		LEFT JOIN userinformation UI
		ON AL.creatorid = UI.uid -- This has to be fixed. The uiid, rather than uid is getting stored.
		WHERE AL.linkid = ID LIMIT 1;

		LEAVE NS_ARTICLE;

	ELSEIF ACTION = 'DISPLAYARTICLETITLE' THEN
		SELECT AL.title
		FROM articlelinks AL
		WHERE AL.linkid = ID LIMIT 1;

		LEAVE NS_ARTICLE;

	ELSEIF ACTION = 'SUBMITARTICLE' THEN
		INSERT INTO articleunreviewed (title, category, body, status, type, creatorid)
		SELECT TITLE, CATEGORY, ARTICLE, '0', '2', USERID
		FROM users U INNER JOIN session S
		ON U.uid = S.uid
		WHERE S.ipaddress = IPADDRESS AND S.passcode = PASSCODE AND S.uid = USERID
		LIMIT 1;
		
		SELECT true AS success;
		LEAVE NS_ARTICLE;

	ELSEIF ACTION = 'SUBMITLINK' THEN
		INSERT INTO articleunreviewed (title, category, link, status, type, creatorid)
		SELECT TITLE, CATEGORY, LINK, '0', '1', USERID
		FROM users U INNER JOIN session S
		ON U.uid = S.uid
		WHERE S.ipaddress = IPADDRESS AND S.passcode = PASSCODE AND S.uid = USERID
		LIMIT 1;

		SELECT true AS success;
		LEAVE NS_ARTICLE;

	ELSEIF ACTION = 'DIRECTPUBLISHARTICLE' THEN
		INSERT INTO article (body)
		VALUES (ARTICLE);
		
		INSERT INTO articlelinks (linktype, title, category, articleid, creatorid)
		VALUES ('2', TITLE, CATEGORY, LAST_INSERT_ID(), USERID);

		SELECT true AS success;
		LEAVE NS_ARTICLE;

	ELSEIF ACTION = 'DIRECTPUBLISHLINK' THEN
		INSERT INTO articlelinks (linktype, title, category, link, creatorid)
		VALUES ('1', TITLE, CATEGORY, LINK, USERID);

		SELECT true AS success;
		LEAVE NS_ARTICLE;

	ELSEIF ACTION = 'PUBLISHUNREVIEWED' THEN
		INSERT INTO article (body)
		SELECT AR.body
		FROM users U INNER JOIN session S
		ON U.uid = S.uid AND S.ipaddress = IPADDRESS AND S.passcode = PASSCODE AND S.uid = USERID
		INNER JOIN articleunreviewed AR
		ON AR.aurid = ID
		WHERE U.accounttype > 2 LIMIT 1;

		INSERT INTO articlelinks (linktype, title, category, link, creatorid, articleid)
		SELECT AR.type, AR.title, AR.category, AR.link, AR.creatorid, LAST_INSERT_ID()
		FROM users U INNER JOIN session S
		ON U.uid = S.uid AND S.ipaddress = IPADDRESS AND S.passcode = PASSCODE AND S.uid = USERID
		AND U.accounttype > 2
		INNER JOIN articleunreviewed AR
		ON AR.aurid = ID LIMIT 1;

		
		UPDATE articleunreviewed AR
		SET AR.status = 2
		WHERE AR.aurid = ID;

	ELSEIF ACTION = 'DELETEUNREVIEWED' THEN
		DELETE AR
		FROM articleunreviewed AR INNER JOIN users U 
		ON U.uid = USERID AND AR.aurid = ID
		INNER JOIN session S
		ON U.uid = S.uid AND S.ipaddress = IPADDRESS AND S.passcode = PASSCODE AND U.accounttype > 2; 

	ELSEIF ACTION = 'GETARTICLEREDIRECT' THEN
		SELECT AL.linktype, AL.link, AL.articleid
		FROM articlelinks AL
		WHERE AL.linkid = ID; 

	ELSEIF ACTION = 'ADDBOOKMARK' THEN
		INSERT INTO articlebookmarks (uid, linkid)
		SELECT USERID, ID
		FROM users U INNER JOIN session S
		ON U.uid = S.uid AND S.ipaddress = IPADDRESS AND S.sessionid = SESSION AND S.uid = USERID;
		
	ELSEIF ACTION = 'REMOVEBOOKMARK' THEN
		DELETE AB
		FROM articlebookmarks AB INNER JOIN users U 
		ON AB.uid = U.uid
		INNER JOIN session S
		ON S.uid = U.uid AND S.ipaddress =IPADDRESS AND S.passcode = PASSCODE AND S.uid = USERID
		WHERE AB.uid = USERID AND AB.linkid = ID;

	ELSEIF ACTION = 'UNREVIEWEDLIST' THEN
		SELECT AUR.title, AUR.category, AUR.body, AUR.aurid AS id, AUR.createdate, AUR.type, CONCAT(UI.firstName, ' ', UI.lastName) AS author
		FROM articleunreviewed AUR INNER JOIN session S
		ON S.ipaddress = IPADDRESS AND S.passcode = PASSCODE
		AND S.sessionid = SESSIONID
		INNER JOIN users U
		ON S.uid = U.uid  AND U.uid = USERID 
		INNER JOIN userinformation UI
		ON UI.uid = AUR.creatorid
		WHERE U.accounttype > 2 AND AUR.status <> 2;

	END IF;


END$$

CREATE DEFINER=`juggerjo`@`localhost` PROCEDURE `NS_ARTICLE_SEARCH` (IN `USERID` BIGINT, IN `PASSCODE` VARCHAR(500), IN `IPADDRESS` VARCHAR(16), IN `ACTION` VARCHAR(200), IN `FILTER` VARCHAR(5), IN `CATEGORY` VARCHAR(20), IN `SEARCHTERM` VARCHAR(2000), IN `PAGENUM` INT, IN `PERPAGE` INT)  NS_ARTICLE_SEARCH:BEGIN
	DECLARE PP INT DEFAULT 50; 
	DECLARE PN INT DEFAULT 0; 
	DECLARE CSR INT DEFAULT 0; 

	IF IFNULL(PAGENUM,0) > 1 THEN
		SET PN = PAGENUM - 1;
	END IF;

	IF IFNULL(PERPAGE,0) <> 0 THEN
		SET PP = PERPAGE;
	END IF;

	SET CSR = PP * PN;

	IF action = 'SEARCH' THEN
		SELECT AL.title, AL.linktype, AL.link AS httplink, AL.linkid AS id, DATE_FORMAT(AL.createdate, '%b %d, %Y (%r)') AS createdate, AL.numcomments, AL.category, AI.pathname
		FROM articlelinks AL LEFT JOIN articleimages AI
		ON AL.imageid = AI.imageid
		WHERE (AL.category = CATEGORY OR IFNULL(CATEGORY,'') = '') AND AL.creatorid <> 'null'
		AND (MATCH (AL.title) AGAINST (CONCAT("'",REPLACE(SEARCHTERM, ' ', "*' '"), "*'")  IN BOOLEAN MODE) OR IFNULL(SEARCHTERM,'')='')
                ORDER BY AL.linkid desc
		LIMIT CSR, PP;

	ELSEIF action = 'COUNT' THEN
		SELECT CEIL(COUNT(1)/ PP) AS count
		FROM articlelinks AL
		WHERE AL.category = CATEGORY OR IFNULL(CATEGORY,'') = '' AND AL.creatorid <> 'null'
		AND (MATCH (AL.title) AGAINST (CONCAT("'",REPLACE(SEARCHTERM, ' ', "*' '"), "*'")  IN BOOLEAN MODE) OR IFNULL(SEARCHTERM,'')='')
		LIMIT CSR, PP;
	END IF;


END$$

CREATE DEFINER=`juggerjo`@`localhost` PROCEDURE `NS_COMMENT` (IN `USERID` BIGINT, IN `PASSCODE` VARCHAR(500), IN `SESSIONID` VARCHAR(100), IN `IPADDRESS` VARCHAR(16), IN `ACTION` VARCHAR(200), IN `COMMENT` VARCHAR(200), IN `LINKID` BIGINT, IN `PCOMMENTID` BIGINT, IN `PAGENUM` BIGINT, IN `PERPAGE` BIGINT)  BEGIN
	DECLARE PP INT DEFAULT 50; 
	DECLARE PN INT DEFAULT 0; 
	DECLARE CSR INT DEFAULT 0; 

	IF IFNULL(PAGENUM,0) > 1 THEN
		SET PN = PAGENUM - 1;
	END IF;

	IF IFNULL(PERPAGE,0) <> 0 THEN
		SET PP = PERPAGE;
	END IF;

	SET CSR = PP * PN;

	IF ACTION = 'ADDCOMMENT' THEN
		
		INSERT INTO comments (linkid, pcid, body, creatorid)
		SELECT LINKID, PCOMMENTID, COMMENT, USERID
		FROM users U INNER JOIN session S
		ON U.uid = S.uid
		WHERE S.ipaddress = IPADDRESS AND S.sessionid = SESSIONID AND S.uid = USERID AND S.passcode = PASSCODE;
		
		
		UPDATE comments C 
		INNER JOIN session S
		ON S.ipaddress = IPADDRESS AND S.sessionid = SESSIONID AND S.uid = USERID AND S.passcode = PASSCODE
		SET C.haschild = 1
		WHERE C.cid = PCOMMENTID;

		
		UPDATE articlelinks AL
		INNER JOIN session S
		ON S.ipaddress = IPADDRESS AND S.sessionid = SESSIONID AND S.uid = USERID AND S.passcode = PASSCODE AND AL.linkid = LINKID
		SET AL.numcomments = AL.numcomments + 1;

	ELSEIF ACTION = 'EDITCOMMENT' THEN
		UPDATE comments C INNER JOIN users U
		ON C.creatorid = U.uid INNER JOIN session S
		ON U.uid = S.uid
		SET C.body = COMMENT
		WHERE S.ipaddress = IPADDRESS AND S.sessionid = SESSIONID AND S.uid = USERID AND S.passcode = PASSCODE;

	ELSEIF ACTION = 'MYCOMMENTS' THEN
		SELECT AL.title, AL.linkid, C.body, CS.body, UI.nicname
		FROM session S INNER JOIN users U
		ON U.uid = S.uid AND S.ipaddress = IPADDRESS AND S.sessionid = SESSIONID AND S.uid = USERID AND S.passcode = PASSCODE
		INNER JOIN userinformation UI
		ON UI.uid = U.uid
		INNER JOIN comments C 
		ON C.creatorid = S.uid
		INNER JOIN articlelink AL
		ON AL.linkid = C.linkid
		LEFT JOIN comments C2
		ON C2.cid = C.pcid
		WHERE C.creatorid = USERID;
	
	ELSEIF ACTION = 'LISTCOMMENTS' THEN
		SELECT C.body AS 'comment'
				, DATE_FORMAT(C.createdate, '%b %d, %Y (%r)') AS createdate
				, C.revisedate
				, UPPER(CONCAT(UI.firstName, ' ', UI.lastName)) AS author, UI.uid AS userid
		FROM comments C LEFT JOIN userinformation UI
		ON UI.uid = C.creatorid
		WHERE C.linkid = LINKID
		ORDER BY C.createdate DESC
		LIMIT CSR, PP;

	ELSEIF ACTION = 'LISTCOMMENTSCOUNT' THEN
		SELECT CEIL(COUNT(*)/ PP) AS count
		FROM comments C 
		WHERE C.linkid = LINKID;

	END IF;

END$$

CREATE DEFINER=`juggerjo`@`localhost` PROCEDURE `NS_MESSAGE` (IN `ACTION` VARCHAR(200), IN `SESSIONID` VARCHAR(500), IN `PASSCODE` VARCHAR(500), IN `IPADDRESS` VARCHAR(16), IN `USERID` BIGINT, IN `RECIEVERID` BIGINT, IN `MESSAGEID` BIGINT, IN `TITLE` VARCHAR(200), IN `MESSAGE` VARCHAR(2000), IN `VAREXT1` VARCHAR(200), IN `PAGENUM` BIGINT, IN `PERPAGE` BIGINT)  JB_MESSAGE: BEGIN
	DECLARE PP INT DEFAULT 50;
	DECLARE PN INT DEFAULT 0;
	DECLARE CSR INT DEFAULT 0;

	IF IFNULL(pagenum,0) > 1 THEN
		SET PN = pagenum - 1;
	END IF;

	IF IFNULL(perpage,0) <> 0 THEN
		SET PP = perpage;		
	END IF;

	SET CSR = PP * PN;
	
	IF ACTION = 'SENDMESSAGE' THEN
		INSERT INTO messageexchange(senderuid, recieveruid, title, message, appendcontactinfo)
		SELECT USERID, RECIEVERID, TITLE, MESSAGE, VAREXT1
		FROM users U INNER JOIN session S WHERE S.uid = U.uid AND U.uid = USERID AND S.passcode = PASSCODE AND S.ipaddress = IPADDRESS AND S.sessionid = SESSIONID
		AND (U.accounttype IN (2,3) OR (U.accounttype = 1 AND (SELECT 1 FROM messageexchange ME WHERE ME.recieveruid = USERID AND ME.senderuid = RECIEVERID LIMIT 1)));

		SELECT 1 AS success;
		LEAVE JB_MESSAGE;

	ELSEIF ACTION = 'MESSAGEHISTORYLIST' THEN
		SELECT 	ME.meid AS id
				, ME.title
				, LEFT(ME.message, 200) AS message
				, CONCAT(S.firstName, ' ', S.lastName) AS sender
				, CONCAT(R.firstName, ' ', R.lastName) AS reciever
				, ME.createdate
				, ME.viewed
		FROM messageexchange ME 
		INNER JOIN userinformation S
		ON ME.senderuid = S.uid
		INNER JOIN userinformation R
		ON ME.recieveruid = R.uid
		WHERE USERID IN (ME.senderuid, ME.recieveruid)
		ORDER BY ME.createdate DESC
		LIMIT CSR, PP;

		SELECT 1 AS success;
		LEAVE JB_MESSAGE;

	ELSEIF ACTION = 'MESSAGEHISTORYCOUNTLIST' THEN
		SELECT (COUNT(*)/PP) AS count
		FROM messageexchange ME 
		INNER JOIN userinformation S
		ON ME.senderuid = S.uid
		INNER JOIN userinformation R
		ON ME.recieveruid = R.uid
		WHERE USERID IN (ME.senderuid, ME.recieveruid);

		SELECT 1 AS success;
		LEAVE JB_MESSAGE;

	ELSEIF ACTION = 'MYSTOREDMESSAGELIST' THEN
		SELECT M.title, M.mid
		FROM message M INNER JOIN session S
		WHERE M.uid = S.uid AND S.passcode = PASSCODE AND S.ipaddress = IPADDRESS AND M.uid = USERID;

		LEAVE JB_MESSAGE;
	ELSEIF ACTION = 'STOREMESSAGE' THEN
		INSERT INTO message (uid, title, message)
		SELECT USERID, TITLE, MESSAGE
		FROM session S 
		WHERE S.passcode = PASSCODE AND S.ipaddress = IPADDRESS AND S.uid = USERID LIMIT 1;

		SELECT 1 AS success, LAST_INSERT_ID() AS messageid;
		LEAVE JB_MESSAGE;
	ELSEIF ACTION = 'EDITSTOREDMESSAGE' THEN
		UPDATE message M, session S
		SET M.title = TITLE, M.message = MESSAGE, M.revisedate = CURRENT_TIMESTAMP
		WHERE S.uid = M.uid AND M.mid = MESSAGEID AND  S.ipaddress = IPADDRESS AND S.uid = USERID;

		SELECT 1 AS success;
		LEAVE JB_MESSAGE;
	ELSEIF ACTION = 'VIEWSTOREDMESSAGE' THEN
		SELECT M.title, M.message, M.mid
		FROM message M INNER JOIN session S
		ON S.uid = M.uid
		WHERE M.uid = USERID AND M.mid = MESSAGEID AND  S.passcode = PASSCODE AND S.ipaddress = IPADDRESS;

		SELECT 1 AS success;
		LEAVE JB_MESSAGE;
	ELSEIF ACTION = 'VIEWMESSAGE' THEN
		SELECT M.title
			, M.message
			, M.meid
			, CONCAT(SENDER.firstName, ' ', SENDER.lastName) AS sender
			, CONCAT(RECIEVER.firstName, ' ', RECIEVER.lastName) AS reciever
			, M.createdate
		FROM messageexchange M INNER JOIN session S
		ON S.uid IN (M.senderuid, M.recieveruid)
		INNER JOIN userinformation SENDER
		ON SENDER.uid = M.senderuid
		INNER JOIN userinformation RECIEVER
		ON RECIEVER.uid = M.recieveruid
		WHERE USERID IN (M.senderuid, recieveruid) AND M.meid = MESSAGEID AND  S.passcode = PASSCODE AND S.ipaddress = IPADDRESS;

		UPDATE messageexchange
		SET viewed = 1
		WHERE meid = MESSAGEID AND recieveruid = USERID;

		SELECT 1 AS success;
		LEAVE JB_MESSAGE;
	ELSEIF ACTION = 'DELETESTOREDMESSAGE' THEN
		DELETE M 
		FROM message M INNER JOIN session S
		ON M.uid = S.uid
		WHERE M.mid = MESSAGEID  AND  S.passcode = PASSCODE AND S.ipaddress = IPADDRESS AND S.uid = USERID;

		SELECT 1 AS success;
		LEAVE JB_MESSAGE;
	END IF;
	
	SELECT 0 AS success;
END$$

CREATE DEFINER=`juggerjo`@`localhost` PROCEDURE `NS_USER` (IN `EMAIL` VARCHAR(200), IN `PASSWORD` VARCHAR(200), IN `ACTION` VARCHAR(200), IN `SESSIONID` VARCHAR(500), IN `FIRSTNAME` VARCHAR(200), IN `LASTNAME` VARCHAR(200), IN `EDUCATION` VARCHAR(200), IN `CAREERLVL` VARCHAR(200), IN `POSTALCODE` VARCHAR(20), IN `COUNTRY` VARCHAR(200), IN `REGION` VARCHAR(200), IN `CITY` VARCHAR(200), IN `ADDRESS1` VARCHAR(200), IN `ADDRESS2` VARCHAR(200), IN `ADDRESS3` VARCHAR(200), IN `PHONE1` VARCHAR(30), IN `USERID` INT, IN `PASSCODE` VARCHAR(500), IN `IPADDRESS` VARCHAR(16), IN `VAREXT1` VARCHAR(200), IN `VAREXT2` VARCHAR(200), IN `VAREXT3` VARCHAR(200))  JB_USER: BEGIN

	IF ACTION = 'SIGNUPUSER' THEN

		IF NOT EXISTS(SELECT 1 FROM users U WHERE U.email = LOWER(EMAIL)) THEN
			SET @SALT = FLOOR(1 + (RAND() * 10000));

			INSERT INTO users (email, password, salt,status)
			VALUES (LOWER(EMAIL), HASH(CONCAT(PASSWORD, @SALT)), @SALT, 0); 

			INSERT INTO location (country, region, city, address1, address2, address3, postalCode)
			VALUES (COALESCE(LOWER(COUNTRY), '')
					, COALESCE(LOWER(REGION), '')
					, COALESCE(LOWER(CITY), '')
					, COALESCE(LOWER(ADDRESS1),'')
					, COALESCE(LOWER(ADDRESS2), '')
					, COALESCE(LOWER(ADDRESS3), '')
					, COALESCE(LOWER(POSTALCODE),''));

			INSERT INTO userinformation (uid, firstName, lastName, careerLvl, education, lid, phone1)
			SELECT U.uid, FIRSTNAME, LASTNAME, '', '', LAST_INSERT_ID(), PHONE1 
			FROM users U WHERE U.email = LOWER(EMAIL);

			SELECT 1 AS success;

			LEAVE JB_USER;
		END IF;

	ELSEIF ACTION = 'UPDATEUSER' THEN

		UPDATE location L, session S, userInformation UI
		SET L.country = LOWER(COUNTRY), L.city = LOWER(CITY)
			, L.address1 = LOWER(ADDRESS1), L.address2 = LOWER(ADDRESS2)
			, L.address3 = LOWER(ADDRESS3), L.postalcode = LOWER(POSTALCODE)
			, L.region = UPPER(REGION)
		WHERE L.lid = UI.lid AND UI.uid = S.uid AND S.uid = USERID AND S.passcode = PASSCODE AND S.ipaddress = IPADDRESS;

		UPDATE userInformation UI, session S
		SET UI.firstName= FIRSTNAME, UI.lastName=LASTNAME, UI.phone1 = PHONE1
		WHERE UI.uid = S.uid AND S.uid = USERID AND S.passcode = PASSCODE AND S.ipaddress = IPADDRESS;

		SELECT 1 AS success;
		LEAVE JB_USER;
	ELSEIF ACTION = 'CHANGEPASSWORD' THEN

		IF EXISTS (SELECT 1 FROM users U INNER JOIN session S ON S.uid = U.uid WHERE S.passcode = PASSCODE AND U.email = EMAIL LIMIT 1) THEN
			SET @SALT = FLOOR(1 + (RAND() * 10000));
			INSERT INTO log(log)
			VALUES ('set');

			UPDATE users U, session S
			SET U.password = HASH(CONCAT(VAREXT1, @SALT)), U.salt = @SALT
			WHERE U.uid = S.uid AND U.email = EMAIL AND S.ipaddress = IPADDRESS AND S.passcode = PASSCODE
			AND S.sessionid = SESSIONID ;

			INSERT INTO log(log)
			VALUES ('set2');


			SELECT 1 AS success;
			LEAVE JB_USER;
		END IF;

	ELSEIF ACTION = 'USERDETAILS' THEN 
		SELECT U.email, UI.*, L.*, UPPER(L.region) AS province, UPPER(L.region) AS state, UI.phone1 AS phone
		FROM users U INNER JOIN userInformation UI
		ON U.uid = UI.uid
		LEFT JOIN location L
		ON UI.lid = L.lid
		INNER JOIN session S
		ON S.uid = U.uid
		WHERE U.uid = USERID AND S.passcode = PASSCODE AND S.ipaddress = IPADDRESS;
		
		LEAVE JB_USER;

	ELSEIF ACTION = 'STOREFORGOTPASSWORDVCODE' THEN 
		

		IF EXISTS (SELECT 1 FROM users U WHERE U.email = EMAIL) THEN
			DELETE V FROM verificationcodes V INNER JOIN users U
			ON U.uid = V.uid
			WHERE U.email = EMAIL;

			INSERT INTO verificationcodes (uid, verificationcode, type)
			SELECT U.uid, PASSCODE, 1
			FROM users U WHERE U.email = EMAIL;

			SELECT 1 AS success;
		ELSE
			SELECT 2 AS success;
		END IF;

		LEAVE JB_USER;

	ELSEIF ACTION = 'CHANGEFORGOTTENPASSWORD' THEN
		IF EXISTS(	SELECT 1 
					FROM users U INNER JOIN verificationcodes V
					ON U.uid = V.uid 
					WHERE U.email = EMAIL AND V.verificationcode = PASSCODE AND V.type = 1) THEN
			
			SET @SALT = FLOOR(1 + (RAND() * 10000));
			
			UPDATE users U, verificationcodes V
			SET U.password = HASH(CONCAT(VAREXT1, @SALT)), U.salt = @SALT
			WHERE U.uid = V.uid AND U.email = EMAIL AND V.type = 1 AND V.verificationcode = PASSCODE;
			
			DELETE V 
			FROM verificationcodes V INNER JOIN users U
			ON V.uid = U.uid
			WHERE U.email = EMAIL;			
			
			SELECT 1 AS success;
			
			LEAVE JB_USER;

		END IF;

	END IF;
	
	SELECT 0 AS success;
END$$

CREATE DEFINER=`juggerjo`@`localhost` PROCEDURE `NS_USERCREDENTIALS` (`EMAIL` VARCHAR(200), `ACTION` VARCHAR(200), `SESSIONID` VARCHAR(200), `PASSWORD` VARCHAR(200), `IPADDRESS` VARCHAR(16), `PASSCODE` VARCHAR(200))  JB_USERCREDENTIALS:BEGIN

	IF ACTION = 'LOGIN' THEN
		IF EXISTS(SELECT 1 FROM users U WHERE U.email = EMAIL AND U.password = HASH(CONCAT(PASSWORD, U.salt)) AND U.accounttype <> 0 AND U.status <> 0) THEN
			
			DELETE S
			FROM session S INNER JOIN users U
			ON S.uid = U.uid
			WHERE U.email = EMAIL;		
			
			UPDATE users U
			SET U.lastlogindate = NOW()
			WHERE U.email = EMAIL AND U.password = HASH(CONCAT(PASSWORD, U.salt));

			INSERT INTO session (uid, sessionid, ipaddress, passcode)
			SELECT U.uid, sessionid, ipaddress, passcode
			FROM users U WHERE U.email=EMAIL AND U.password = HASH(CONCAT(PASSWORD, U.salt));

			SELECT true AS success, 0 AS status,'Successful Login' AS message;
			LEAVE JB_USERCREDENTIALS;
 
		ELSEIF EXISTS(SELECT 1 FROM users U WHERE U.email = EMAIL AND U.password = HASH(CONCAT(PASSWORD, U.salt)) AND (U.accounttype = 0 OR U.status = 0)) THEN
			SELECT false AS success, 1 AS status,'You havent activated your account or the admin has blocked your access' AS message;
		END IF;

	ELSEIF ACTION = 'VERIFY' THEN
		SELECT S.createdate, U.email, U.uid, U.status, U.accounttype
		FROM session S INNER JOIN users U
		ON S.uid = U.uid
		WHERE S.sessionid = SESSIONID AND S.ipaddress = IPADDRESS AND S.passcode = PASSCODE AND U.email = EMAIL;

		LEAVE JB_USERCREDENTIALS;

	ELSEIF ACTION = 'LOGOUT' THEN
		DELETE S FROM session S 
		WHERE S.sessionid = SESSIONID AND S.passcode = PASSCODE;

		SELECT S.uid FROM session S
		WHERE S.sessionid = SESSIONID AND S.passcode = PASSCODE;
		
		LEAVE JB_USERCREDENTIALS;

	ELSEIF ACTION = 'STOREVCODE' THEN
		
		DELETE V FROM verificationcodes V INNER JOIN users U
		ON U.uid = V.uid
		WHERE U.email = EMAIL;

		INSERT INTO verificationcodes (uid, verificationcode, type)
		SELECT U.uid, PASSCODE, 0
		FROM users U WHERE U.email = EMAIL;

		SELECT true AS success;

		LEAVE JB_USERCREDENTIALS;

	ELSEIF ACTION = 'ACTIVATEEMPLOYER' THEN
		IF EXISTS(	SELECT 1 
					FROM users U INNER JOIN verificationcodes V
					ON U.uid = V.uid 
					WHERE U.email = EMAIL AND V.verificationcode = PASSCODE AND V.type = 0) THEN
			UPDATE users U, verificationcodes V
			SET U.status = 1, U.accounttype = 2
			WHERE U.uid = V.uid AND U.email = EMAIL AND V.type = 0;

			DELETE V 
			FROM verificationcodes V INNER JOIN users U
			ON V.uid = U.uid
			WHERE U.email = EMAIL;			

			SELECT true AS success;

			LEAVE JB_USERCREDENTIALS;
		END IF;

	ELSEIF ACTION = 'ACTIVATEEMPLOYEE' THEN
		IF EXISTS(	SELECT 1 
					FROM users U INNER JOIN verificationcodes V
					ON U.uid = V.uid 
					WHERE U.email = EMAIL AND V.verificationcode = PASSCODE AND V.type = 0) THEN
			UPDATE users U, verificationcodes V
			SET U.status = 1, U.accounttype = 1
			WHERE U.uid = V.uid AND U.email = EMAIL AND V.type = 0;

			DELETE V 
			FROM verificationcodes V INNER JOIN users U
			ON V.uid = U.uid
			WHERE U.email = EMAIL;			

			SELECT true AS success;
			LEAVE JB_USERCREDENTIALS;
		END IF;	

	END IF;

	SELECT false AS success, 0 AS status, 'Invalid Input' AS message;
END$$

CREATE DEFINER=`juggerjo`@`localhost` PROCEDURE `NS_USER_DETAIL` (IN `ACTION` VARCHAR(200), IN `UID` INT)  BEGIN
	IF ACTION = 'DETAILS' THEN
		SELECT UI.firstName, UI.lastName, D.realval AS careerLvl, D2.realval AS education
		FROM userinformation UI LEFT JOIN dictionary D
		ON UI.careerLvl = D.val AND D.col = "careerLvl"
		LEFT JOIN dictionary D2
		ON UI.education = D2.val AND D2.col = "education"
		WHERE UI.uid = UID;

	ELSEIF ACTION = 'SKILLS' THEN
		SELECT US.name AS skillname, US.experience, US.lastused 
		FROM userskills US
		WHERE US.uid = UID;

	END IF;

END$$

CREATE DEFINER=`juggerjo`@`localhost` PROCEDURE `TRACKER` (IN `IPADDRESS` VARCHAR(300))  BEGIN
        DECLARE USERVISITDATE DATE;
        SET USERVISITDATE = CURDATE();
	
		INSERT INTO visitortracker(ipaddress, visitdate)
	    SELECT IPADDRESS, USERVISITDATE
        FROM (select 1 t) t
        WHERE IPADDRESS NOT IN (select v.ipaddress FROM visitortracker v WHERE visitdate = USERVISITDATE);
    
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `article`
--

CREATE TABLE `article` (
  `articleid` bigint(20) NOT NULL,
  `body` longtext CHARACTER SET utf8 COLLATE utf8_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `article`
--

INSERT INTO `article` (`articleid`, `body`) VALUES
(1, 'I just wanted to say hi, and ask all reader to describe in the comments how they found this site.<br/><br/>I hope you found the articles informative.'),
(2, 'I just wanted to say hi, and ask all reader to describe in the comments how they found this site.<br/><br/>I hope you found the articles informative.'),
(3, NULL),
(4, NULL),
(5, NULL),
(6, NULL),
(7, NULL),
(8, NULL),
(9, NULL),
(10, NULL),
(11, NULL),
(12, NULL),
(13, NULL),
(14, NULL),
(15, NULL),
(16, NULL),
(17, NULL),
(18, NULL),
(19, NULL),
(20, NULL),
(21, NULL),
(22, 'If a popup appears, it does.<script>alert(\'YES! This site can be HACKED!\')</script>'),
(23, 'When it is ajar.'),
(24, 'He who asks a question, is a fool for 5 min; He who doesn\'t ask a question remains a fool forever.- Chinese Proverb');

-- --------------------------------------------------------

--
-- Table structure for table `articlebookmarks`
--

CREATE TABLE `articlebookmarks` (
  `uid` bigint(20) NOT NULL,
  `linkid` bigint(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `articleimages`
--

CREATE TABLE `articleimages` (
  `imageid` bigint(20) NOT NULL,
  `pathname` varchar(2000) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `articleimages`
--

INSERT INTO `articleimages` (`imageid`, `pathname`) VALUES
(1, 'http://peoot.com/src/custom/img/articles/46/dn.jpg'),
(2, 'http://peoot.com/src/custom/img/articles/51/l.jpg'),
(3, 'http://peoot.com/src/custom/img/articles/48/rape.jpg'),
(4, 'http://peoot.com/src/custom/img/articles/53/megan.jpg'),
(5, 'http://peoot.com/src/custom/img/articles/19/jae.jpg'),
(6, 'http://peoot.com/src/custom/img/articles/42/trend.jpg'),
(7, 'http://peoot.com/src/custom/img/articles/64/bat.jpg'),
(8, 'http://peoot.com/src/custom/img/articles/59/ph.jpg'),
(9, 'http://peoot.com/src/custom/img/articles/69/sg.jpg'),
(10, 'http://peoot.com/src/custom/img/articles/67/tony.jpg');

-- --------------------------------------------------------

--
-- Table structure for table `articlelinks`
--

CREATE TABLE `articlelinks` (
  `linkid` bigint(20) NOT NULL,
  `linktype` int(11) NOT NULL,
  `link` varchar(500) DEFAULT NULL,
  `imageid` bigint(20) NOT NULL,
  `title` varchar(110) DEFAULT NULL,
  `category` varchar(200) DEFAULT NULL,
  `articleid` bigint(20) NOT NULL DEFAULT '0',
  `createdate` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `revisedate` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `voteup` bigint(20) NOT NULL DEFAULT '0',
  `votedown` bigint(20) NOT NULL DEFAULT '0',
  `voteinternal` bigint(20) NOT NULL DEFAULT '0',
  `creatorid` bigint(20) NOT NULL,
  `numcomments` bigint(20) NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `articlelinks`
--

INSERT INTO `articlelinks` (`linkid`, `linktype`, `link`, `imageid`, `title`, `category`, `articleid`, `createdate`, `revisedate`, `voteup`, `votedown`, `voteinternal`, `creatorid`, `numcomments`) VALUES
(2, 1, 'http://www.youtube.com/watch?v=pB4aA4eO8wY', 0, 'Korean Girl Harassment Video, Real or Fake?', 'society', 0, '2013-07-29 01:37:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 1),
(3, 1, 'http://movies.nytimes.com/2013/05/17/movies/pieta-directed-by-kim-ki-duk.html', 0, 'Korean Cinema: Pieta, Directed By Kim Ki Duk', 'cinema', 0, '2013-07-29 01:43:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(4, 1, 'http://www.youtube.com/watch?v=ZIRdTnQrDIg', 0, 'What Woman Think vs What Men Think', 'sexndating', 0, '2013-07-29 01:46:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(5, 1, 'http://www.toplessrobot.com/2013/02/super_terrific_japanese_thing_penis_powered_game_c.php', 0, 'Japanese Penis Operated Remote Controller', 'scintech', 0, '2013-07-29 01:48:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(6, 1, 'http://www.news.wisc.edu/21970', 0, 'Hormones May Usher Abused Girls Into Early Adulthood', 'scintech', 0, '2013-07-29 02:06:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(7, 1, 'http://www.cbsnews.com/8301-504803_162-57399227-10391709/do-you-have-trouble-recognizing-faces-take-a-test/', 0, 'Are You Face Blind? Take The Test!', 'body', 0, '2013-07-29 02:43:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(8, 1, 'http://www.priceplow.com/blog/soylent-subterfuge', 0, 'Soylent - A Liquid That Can Replace All Food?', 'scintech', 0, '2013-07-29 02:46:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(9, 1, 'http://www.fhm.com/girls/100-sexiest-women', 0, '100 Sexiest Girls - 2013', 'sexndating', 0, '2013-07-29 02:48:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(10, 1, 'http://www.theawl.com/2013/07/rape-joke-patricia-lockwood', 0, 'The Rape Joke - A Poem By Patricia Lockwood', 'society', 0, '2013-07-29 02:56:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(11, 1, 'http://www.npr.org/2013/07/28/206231873/who-spies-more-the-united-states-or-europe', 0, 'Who Spies On Citizens More? The US or Europe?', 'society', 0, '2013-07-29 02:58:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(12, 1, 'http://www.reuters.com/article/2013/07/28/net-us-hackers-cars-idUSBRE96R06120130728', 0, 'Software Hackers To Release Car Hacking Code At Next Meet ', 'scintech', 0, '2013-07-29 03:25:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(13, 1, 'http://www.bbc.co.uk/news/science-environment-23462815', 0, 'The Secret Of Usain Bolt\'s Speed According To Physics', 'scintech', 0, '2013-07-29 03:34:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(14, 1, 'http://www.popsci.com/science/article/2013-07/could-asteroid-impact-knock-moon-earth', 0, 'Could An Astroid Impact Knock The Moon Into The Earth?', 'scintech', 0, '2013-07-29 03:41:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(15, 1, 'http://www.huffingtonpost.com/2013/05/13/losing-virginity-stories-11-women-first-time-having-sex_n_3267987.html', 0, '11 Woman Open Up About Loosing Their Virginity', 'sexndating', 0, '2013-07-29 04:41:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(16, 1, 'http://www.jeffwillet.com/newsite/2011/09/what-is-max-ot-and-why-is-it-best-for-changing-your-body/', 0, 'What Is Max OT And Why Is It Good For Changing Your Body?', 'body', 0, '2013-07-29 04:44:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(17, 1, 'http://ca.askmen.com/top_10/travel_top_ten_150/180_travel_top_ten.html', 0, 'Top 10 Cheapest Vacation Spots', 'worldnhistory', 0, '2013-07-29 04:48:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(18, 1, 'http://www.huffingtonpost.com/2013/07/28/poverty-unemployment-rates_n_3666594.html', 0, '80% of Adults In US Face Near Poverty At Some Point In Their Lives', 'worldnhistory', 0, '2013-07-29 06:13:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(19, 1, 'http://mma.top5.com/list-of-top-5-deadliest-martial-arts/', 5, '5 Most Deadly Martial Arts', 'body', 0, '2013-07-29 12:33:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(25, 1, 'http://www.bbc.co.uk/news/world-us-canada-23495026', 0, 'FBI saves 105 trafficked children in 76 US cities', 'worldnhistory', 0, '2013-07-29 21:16:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(26, 1, 'http://www.bloomberg.com/news/2013-07-29/why-are-google-employees-so-disloyal-.html', 0, 'Why Are Google Employees So Disloyal?', 'worldnhistory', 0, '2013-07-30 00:27:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(27, 1, 'http://www.gq.com/news-politics/newsmakers/201308/thomas-quick-serial-killer-august-2013', 0, 'The Serial Killer Has Second Thoughts: The Confessions of Thomas Quick', 'society', 0, '2013-07-30 04:38:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(28, 1, 'http://www.buzzfeed.com/mikehayes/105-teenagers-rescued-in-nationwide-sex-trafficking-crackdow', 0, '105 Teenagers Rescued, 150 Pimps Arrested In Nationwide Sex Trafficking Crackdown', 'worldnhistory', 0, '2013-07-30 14:23:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(29, 1, 'http://kotaku.com/japanese-university-makes-special-forever-alone-dinin-947794041?utm_source=feedburner', 0, 'Japanese University Makes Special â€œForever Aloneâ€ Dining Tables', 'worldnhistory', 0, '2013-07-30 14:24:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(30, 1, 'http://www.telegraph.co.uk/news/worldnews/asia/pakistan/10210231/More-than-240-prisoners-escape-in-Pakistan-jailbreak.html', 0, 'More than 240 prisoners escape in Pakistan jailbreak', 'worldnhistory', 0, '2013-07-30 14:25:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(31, 1, 'http://designtaxi.com/news/359660/Infographic-The-Amount-Of-Online-Activity-That-Goes-On-Every-60-Seconds/', 0, 'Infographic: The Amount Of Online Activity That Goes On Every 60 Seconds', 'general', 0, '2013-07-30 14:29:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(32, 1, 'http://www.washingtonpost.com/lifestyle/style/after-the-whistle-revealers-of-government-secrets-share-how-their-lives-have-changed/2013/07/28/23d82596-f613-11e2-9434-60440856fadf_story.html', 0, 'After the whistle: Revealers of government secrets share how their lives have changed', 'worldnhistory', 0, '2013-07-30 14:31:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(33, 1, 'http://www.youtube.com/watch?feature=player_detailpage&v=rsIOoXG_gmo', 0, 'Extreme Homeless Man Makeover!', 'worldnhistory', 0, '2013-07-30 14:40:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(34, 1, 'http://www.careerealism.com/land-interview/', 0, 'Why Can\'t I Get An Interview?', 'society', 0, '2013-07-30 15:51:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(35, 1, 'http://www.nature.com/news/incan-child-mummies-show-evidence-of-sacrificial-rituals-1.13461', 0, 'Incan child mummies show evidence of sacrificial rituals', 'worldnhistory', 0, '2013-07-30 16:09:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(36, 1, 'http://net.tutsplus.com/articles/how-to-become-a-freelance-web-developer/', 0, 'How To Become A Freelance Web Designer', 'society', 0, '2013-07-30 18:27:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(37, 1, 'http://www.nbcnews.com/id/3917414/ns/dateline_nbc/t/face-value/', 0, 'Do Looks Really Matter?', 'society', 0, '2013-07-30 18:46:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(38, 1, 'http://otbxsolutions.ca/index.html', 0, 'An Awesome Job Portfolio Site', 'general', 0, '2013-07-30 18:57:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(39, 1, 'http://www.ted.com/talks/sergey_brin_why_google_glass.html', 0, 'Sergey Brin: Why Google Glasses?', 'scintech', 0, '2013-07-30 19:06:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(40, 1, 'http://laughingsquid.com/porn-sex-vs-real-sex-the-differences-explained-with-food/', 0, 'Porn Sex vs Real Sex: Explained With Food', 'sexndating', 0, '2013-07-30 19:13:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(41, 1, 'http://www.thedailybeast.com/articles/2013/07/28/from-ptsd-to-prison-why-veterans-become-criminals.html', 0, 'Why Veterans Become Criminals', 'society', 0, '2013-07-30 19:18:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(42, 1, 'http://allthingsd.com/20130529/mary-meekers-2013-internet-trends-deck-the-full-video/', 6, 'Mary Meeker: 2013 Internet Trends', 'scintech', 0, '2013-07-30 20:59:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(43, 1, 'http://www.investopedia.com/financial-edge/0511/work-experience-vs.-education-which-lands-you-the-best-job.aspx', 0, 'Work Experience Vs. Education: Which Lands You The Best Job?', 'society', 0, '2013-07-30 21:36:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(44, 1, 'https://www.linkedin.com/today/post/article/20130723160110-658789-7-qualities-of-a-truly-loyal-employee?trk=mp-details-rc', 0, '7 Qualities Of A Truly Loyal Employee', 'society', 0, '2013-07-30 21:42:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 1),
(45, 1, 'http://www.theguardian.com/film/filmblog/2011/dec/30/my-favourite-film-millers-crossing', 0, 'Millers Crossing: My Favorite Film', 'cinema', 0, '2013-07-31 02:00:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(46, 1, 'http://theawesomecritics.com/review/death-note-anime-review/', 1, 'Death Note Anime Review', 'cinema', 0, '2013-07-31 02:03:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(47, 1, 'http://www.themanime.org/viewreview.php?id=969', 0, 'Monster Anime Review', 'cinema', 0, '2013-07-31 02:04:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(48, 1, 'http://www.slate.com/articles/double_x/doublex/2013/07/i_was_raped_at_55_here_is_how_i_responded.html', 3, 'I was raped at 55, here is how I responded', 'society', 0, '2013-07-31 02:48:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 1),
(49, 1, 'http://www.latimes.com/news/nationworld/nation/la-na-cia-management-20130730,0,5485587.story', 0, 'Bad management drives talent from the CIA', 'society', 0, '2013-07-31 02:48:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(50, 1, 'http://www.livescience.com/38546-hall-of-dead-unearthed-england.html', 0, 'Ancient \'Hall of the Dead\' Unearthed in England', 'worldnhistory', 10, '2013-07-31 05:26:24', '0000-00-00 00:00:00', 0, 0, 0, 82, 0),
(51, 1, 'http://www.nihonreview.com/anime/code-geass-lelouch-of-the-rebellion/', 2, 'Code Geass: Lelouch of the Rebellion', 'cinema', 0, '2013-07-31 07:29:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(52, 1, 'http://www.theglobeandmail.com/life/health-and-fitness/health/doctors-salaries-are-on-the-rise-but-services-per-patients-arent-report-says/article13521594/', 0, 'Doctorsâ€™ salaries are on the rise, but services per patients arenâ€™t, report says', 'society', 0, '2013-07-31 08:04:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(53, 1, 'http://www.businessinsider.com/surprising-statistics-about-hot-people-versus-ugly-people-2011-1', 4, 'Surprising Statistics On Hot & Ugly People', 'sexndating', 0, '2013-07-31 18:49:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(54, 1, 'http://answers.yahoo.com/question/index?qid=20081118224912AARrI37', 0, 'Are there any good people in the world?', 'society', 0, '2013-07-31 20:44:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(55, 1, 'http://www.voanews.com/content/zimbabweans-vote-for-president-parliament/1713482.html', 0, 'Fraud Allegations Overshadow Zimbabwe Vote', 'worldnhistory', 0, '2013-07-31 21:10:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(56, 1, 'http://life.nationalpost.com/2013/07/31/self-diagnosis-on-google-other-websites-the-first-line-of-medical-care-for-more-than-half-of-canadians-poll/', 0, 'Self-diagnosis on Google, other websites the first line of medical care for more than half of Canadians', 'general', 0, '2013-07-31 21:11:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(57, 1, 'http://www.adventurouskate.com/', 0, 'Katie The Travel Blogger', 'worldnhistory', 0, '2013-07-31 22:54:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(58, 1, 'http://www.aeonmagazine.com/being-human/why-is-there-still-no-pill-for-men/', 0, 'Why Isn\'t There A Contraceptive Pill For Men?', 'sexndating', 0, '2013-08-01 00:10:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(59, 1, 'http://www.bbc.co.uk/news/magazine-23063492', 8, 'The village where half the population is sex offenders', 'society', 0, '2013-08-01 00:11:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(60, 1, 'http://www.nytimes.com/2013/08/04/magazine/stephen-kings-family-business.html?partner=rss&emc=rss&_r=1&pagewanted=all&', 0, 'Stephen King\'s Family Business', 'society', 0, '2013-08-01 00:12:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(61, 1, 'http://www.pri.org/stories/nasa-funds-warp-speed-research-14547.html', 0, 'NASA\'s warp drive research', 'scintech', 0, '2013-08-01 00:12:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(62, 1, 'http://brokensecrets.com/2013/07/31/why-bars-put-ice-in-the-urinals/', 0, 'Why do bars put ice in their urinals?', 'scintech', 0, '2013-08-01 00:14:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(63, 1, 'http://www.slate.com/articles/business/the_dismal_science/2013/07/renewing_your_passport_visit_the_incredibly_efficient_new_york_city_passport.html', 0, 'The most efficient office in the world', 'worldnhistory', 0, '2013-08-01 00:15:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(64, 1, 'http://laughingsquid.com/the-price-of-being-a-superhero-in-real-life-then-now/', 7, 'The Cost Of Being A Real Super Hero, Past & Present', 'cinema', 0, '2013-08-01 00:17:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(65, 1, 'http://www.theguardian.com/world/2013/jul/31/nsa-top-secret-program-online-data', 0, 'Training tools for NSA spy kit revealed', 'scintech', 0, '2013-08-01 00:20:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(66, 1, 'http://www.extremetech.com/extreme/162678-harvard-creates-brain-to-brain-interface-allows-humans-to-control-other-animals-with-thoughts-alone', 0, 'Harvard creates interface that allows people to control animals with thought', 'scintech', 0, '2013-08-01 00:44:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(67, 1, 'https://www.youtube.com/watch?v=ccKuF_nnPvg', 10, 'Tony Robbins On How To Organize Your Life', 'society', 0, '2013-08-01 02:54:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(68, 1, 'http://www.youtube.com/watch?v=ul35z_ePKjM', 0, 'Awkward Couple Fight', 'sexndating', 0, '2013-08-01 03:15:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(69, 1, 'http://thelibertarianrepublic.com/watch-sexy-nsa-commercial-with-sasha-grey/', 9, 'Watch a sexy NSA commercial with Sasha Grey', 'society', 0, '2013-08-01 17:19:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(70, 1, 'http://blogs.wsj.com/moneybeat/2013/07/08/forget-bitcoins-litecoins-are-the-next-big-thing/', 0, 'Forget Bitcoins, Litecoins are the next big thing.', 'worldnhistory', 0, '2013-08-02 00:24:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(71, 1, 'http://jezebel.com/yale-officially-declares-nonconsensual-sex-not-that-b-988475927', 0, 'Yale Declares Non-Consensual Sex Is Not A Big Deal', 'society', 0, '2013-08-02 01:55:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(72, 1, 'http://www.newyorker.com/online/blogs/sportingscene/2013/07/genetics-searching-for-the-perfect-athlete.html', 0, 'Searching for the perfect athlete', 'scintech', 0, '2013-08-02 02:00:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(73, 1, 'http://www.motherjones.com/politics/2013/08/calculator-fast-food-worker-income-wages-comparison', 0, 'Could you survive on fast food wages?', 'society', 0, '2013-08-02 02:08:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(74, 1, 'http://www.wired.com/gadgetlab/2013/08/inside-story-of-moto-x/', 0, 'Moto X - Google\'s First Smartphone', 'scintech', 0, '2013-08-02 02:34:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(75, 1, 'http://online.wsj.com/article_email/SB10001424127887323997004578641993388259674-lMyQjAxMTAzMDAwMTEwNDEyWj.html', 0, 'The FBI can remotely activate the mic on your phone', 'scintech', 0, '2013-08-03 06:38:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(76, 1, 'http://www.theatlanticwire.com/technology/2013/08/its-may-be-end-apple-store-we-know-it/67907/', 0, 'The end of the Apple store', 'worldnhistory', 0, '2013-08-03 06:39:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(77, 1, 'http://www.nationaljournal.com/magazine/how-much-is-a-life-worth-20130801', 0, 'How much is a life worth?', 'society', 0, '2013-08-03 06:40:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(78, 1, 'http://www.theatlanticwire.com/national/2013/08/texas-running-out-execution-drugs/67902/', 0, 'Texas is running out of execution drugs', 'society', 0, '2013-08-03 06:41:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(79, 1, 'http://www.economist.com/blogs/graphicdetail/2013/08/daily-chart', 0, 'Which country has the most overcrowded prisons?', 'general', 0, '2013-08-03 06:42:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(80, 1, 'http://priceonomics.com/do-14-of-americans-really-suspect-that-president/', 0, 'Do 14% of Americans really think Obama is the anti-christ?', 'society', 0, '2013-08-03 06:42:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(81, 1, 'http://io9.com/the-quantum-zeno-effect-actually-does-stop-the-world-977909459', 0, 'Quantum zeno effect really does stop the world', 'scintech', 0, '2013-08-03 06:43:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(82, 1, 'https://en.wikipedia.org/wiki/E-learning', 0, 'What is E-learning?', 'scintech', 0, '2013-08-03 06:48:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(83, 1, 'http://www.gizmag.com/lunar-laser-communication/28517/', 0, 'NASA and ESA to demonstrate Earth moon laser communication', 'scintech', 0, '2013-08-03 17:19:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(84, 1, 'http://adtmag.com/blogs/watersworks/2013/07/devs-are-kings-panel.aspx', 0, 'The rise of the Developer: Why developers are kings', 'scintech', 0, '2013-08-03 17:20:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(85, 1, 'http://motherboard.vice.com/blog/the-first-manned-mission-to-europa-is-about-to-start-crowd-funding', 0, 'Crowd funding a trip to Jupiter\'s moons', 'society', 0, '2013-08-03 17:20:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(86, 1, 'http://wind8apps.com/surface-pro-price-discount/', 0, 'Microsoft cuts surface pro price by $100', 'scintech', 0, '2013-08-05 11:34:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(87, 1, 'http://bytesizebio.net/index.php/2013/08/03/aphid-attacks-should-be-reported-through-the-fungusphone/', 0, 'Plants communicate using fungus', 'scintech', 0, '2013-08-05 11:35:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(88, 1, 'http://www.washingtonpost.com/national/washington-post-to-be-sold-to-jeff-bezos/2013/08/05/ca537c9e-fe0c-11e2-9711-3708310f6f4d_story.html', 0, 'Washington Post to be sold to Amazon founder', 'society', 0, '2013-08-06 20:37:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(89, 1, 'http://science.nasa.gov/science-news/science-at-nasa/2013/05aug_fieldflip/', 0, 'The sun\'s magnetic field is about to flip', 'scintech', 0, '2013-08-07 05:55:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(90, 1, 'http://www.mentalfloss.com/article/52081/how-pick-lock', 0, 'How to pick a lock', 'scintech', 0, '2013-08-07 11:57:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(91, 1, 'http://www.nbcnews.com/id/14024565/?GT1=8307', 0, 'Homeless man finds that the best reward is honesty', 'worldnhistory', 0, '2013-08-07 17:31:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(92, 1, 'http://edition.cnn.com/2013/08/08/health/gupta-changed-mind-marijuana/index.html', 0, 'Why Dr Gupta changed his mind on weed', 'body', 0, '2013-08-08 16:54:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(93, 1, 'http://www.extremetech.com/extreme/163452-elon-musk-ill-release-the-hyperloop-plans-but-im-too-busy-to-build-it-myself', 0, 'Elon Musk - I\'ll release the hyperloop plans but I\'m too busy to build it', 'scintech', 0, '2013-08-08 17:00:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(94, 1, 'http://www.slate.com/articles/health_and_science/transportation/2013/08/bus_rapid_transit_improved_buses_are_the_best_route_to_better_transit.html', 0, 'The best route to better transit', 'society', 0, '2013-08-08 17:02:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(95, 1, 'http://www.buzzfeed.com/natashavc/barbara-wu-94kb', 0, 'Did this college student really want to kill two of her ex-boyfriends', 'society', 0, '2013-08-08 17:03:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(96, 1, 'http://www.theverge.com/2013/8/8/4602764/game-of-thrones-piracy-better-than-an-emmy-says-time-warner-ceo', 0, 'Game of Thrones is most pirated show in 2012', 'cinema', 0, '2013-08-09 15:35:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(97, 1, 'http://consumerist.com/2013/08/08/dominos-pizza-is-so-used-to-complaints-it-cant-take-a-compliment/', 0, 'Domino\'s Pizza is so used to complaints it cannot take a compliment', 'society', 0, '2013-08-09 15:36:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(98, 1, 'http://betabeat.com/2013/08/clever-cup-changes-color-to-notify-drinkers-of-roofies/', 0, 'Clever cup changes color to notify drinkers of roofies', 'scintech', 0, '2013-08-09 15:37:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(99, 1, 'http://pcdn.500px.net/42710984/137f72d4c3fec2617a997ace98386f7e3fc50d90/1080.jpg', 0, 'Mount Fuji in the morning', 'worldnhistory', 0, '2013-08-09 15:39:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(100, 1, 'https://www.eff.org/deeplinks/2013/07/what-it-means-be-target-or-why-we-once-again-stopped-believing-government-and-once', 0, 'What it means to be an NSA target', 'society', 0, '2013-08-09 15:40:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(101, 1, 'http://flavorwire.com/408275/50-sci-fifantasy-novels-that-everyone-should-read/view-all', 0, '50 sci-fi novels everyone should read', 'worldnhistory', 0, '2013-08-09 15:44:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(102, 1, 'http://slashdot.org/topic/datacenter/microsoft-to-squeeze-datacenters-on-price-of-winserver-2012-r2/', 0, 'Microsoft to Squeeze Datacenters on Price of WinServer 2012 R2', 'scintech', 0, '2013-08-10 01:35:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(103, 1, 'http://www.youtube.com/watch?v=8pTEmbeENF4', 0, 'The future of programming', 'scintech', 0, '2013-08-10 01:37:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(104, 1, 'http://firstread.nbcnews.com/_news/2013/08/09/19950803-snowden-revelations-force-obamas-hand-on-surveillance-program?lite', 0, 'Snowden revelations force Obama\'s hand on surveillance program', 'society', 0, '2013-08-10 01:44:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(105, 1, 'http://priceonomics.com/how-sergey-aleynikov-learned-never-to-talk-to-the/', 0, 'How Sergey Aleynikov Learned Never to Talk to the Police', 'society', 0, '2013-08-10 01:48:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(106, 1, 'http://www.propublica.org/article/how-unpaid-interns-arent-protected-against-sexual-harassment', 0, 'Unpaid Interns are not protected against sexual harassment', 'society', 0, '2013-08-10 01:55:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(107, 1, 'http://uk.finance.yahoo.com/news/payment-by-cash-card-or-face--100337146.html', 0, 'Payment by cash, card or face?', 'scintech', 0, '2013-08-10 03:43:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(108, 1, 'http://uk.finance.yahoo.com/news/greek-youth-unemployment-soars-64-115916638.html', 0, 'Greek youth unemployment soars to 64.9%', 'society', 0, '2013-08-10 03:43:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(109, 1, 'http://www.thedailybeast.com/articles/2013/08/09/fallen-princesses-the-amazing-photos-of-depressed-disney-royalty.html', 0, 'What if your favorite Disney princesses didn\'t live happily ever after?', 'cinema', 0, '2013-08-11 05:01:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(110, 1, 'http://www.cnn.com/2013/08/09/tech/innovation/mars-one-applications', 0, 'More than 100,000 applicants want to go on a one way trip to Mars', 'worldnhistory', 0, '2013-08-11 12:54:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(111, 1, 'http://www.nejm.org/doi/full/10.1056/NEJMoa1215740', 0, 'Study ties high blood pressure to dementia', 'body', 0, '2013-08-12 00:26:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(112, 1, 'http://gawker.com/5850826/nypd-in-super-racist-cop-shocker-again', 0, 'NYPD harbours another super racist cop. SURPRISE!', 'society', 0, '2013-08-12 00:36:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(113, 1, 'http://nerdbastards.com/2013/03/02/ten-inherently-evil-people-according-to-80s-cinema-2/', 0, '10 Inheriently Evil People According To 80s Cinema', 'cinema', 0, '2013-08-12 00:43:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(121, 1, 'http://www.popsci.com/science/article/2013-08/how-often-do-astronauts-do-laundry', 0, 'How often do astronauts do laundry in space?', 'scintech', 0, '2013-08-12 05:35:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(122, 1, 'http://phys.org/news/2013-08-christians-airbrushed-women-history.html', 0, 'Christians airbrushed woman out of history', 'worldnhistory', 0, '2013-08-12 14:41:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(123, 1, 'http://www.motherjones.com/politics/2013/08/meth-pseudoephedrine-big-pharma-lobby', 0, 'Merchants of Meth: How big Pharm keeps Cooks in the business', 'general', 0, '2013-08-12 14:42:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(124, 1, 'http://marginalrevolution.com/marginalrevolution/2013/08/the-animals-are-also-getting-fat.html', 0, 'The average weight of animals are increasing', 'scintech', 0, '2013-08-12 14:43:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(125, 1, 'http://www.dailymail.co.uk/news/article-2388245/Doctors-train-dogs-sniff-Ovarian-cancer-hope-building-cheap-test-diagnose-silent-killer-disease.html', 0, 'Dogs sniff out ovarian cancer', 'scintech', 0, '2013-08-12 14:45:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(126, 1, 'http://thestir.cafemom.com/love_sex/153648/12_Reasons_Your_Man_Doesnt', 0, '12 reasons your man doesn\'t want to have sex with you anymore', 'sexndating', 0, '2013-08-12 15:24:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(127, 1, 'http://arstechnica.com/science/2013/08/new-meta-analysis-checks-the-correlation-between-intelligence-and-faith/', 0, 'Correlation between intelligence and faith', 'scintech', 0, '2013-08-12 20:42:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(128, 1, 'http://www.fastcodesign.com/1671768/bang-with-friends-the-beginning-of-a-sexual-revolution-on-facebook', 0, 'Bang with friends, the beginning of a sexual revolution on Facebook', 'scintech', 0, '2013-08-12 22:47:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(129, 1, 'http://www.wired.com/wiredscience/2013/08/after-death-consciousness-rats/', 0, 'Possible Hints of Consciousness After Death Found in Rats', 'scintech', 0, '2013-08-12 22:48:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(130, 1, 'http://www.esquire.com/features/what-it-feels-like/ESQ0803-AUG_WIFL', 0, 'What it feels like to ...', 'society', 0, '2013-08-12 23:59:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(131, 1, 'http://www.dailymail.co.uk/health/article-1079375/Father-job--employers-think-hes-ugly.html', 0, 'Father-of-two can\'t get a job - because employers think he\'s \'too ugly\'', 'society', 0, '2013-08-13 11:51:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(132, 1, 'http://www.nature.com/news/neanderthals-made-leather-working-tools-like-those-in-use-today-1.13542', 0, 'Neanderthals made leather-working tools like those in use today', 'scintech', 0, '2013-08-13 13:33:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(133, 1, 'http://www.nature.com/news/pentagon-s-giant-blood-serum-bank-may-provide-ptsd-clues-1.13545', 0, 'Pentagonâ€™s giant blood serum bank may provide PTSD clues', 'scintech', 0, '2013-08-13 13:34:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(134, 1, 'http://www.nature.com/news/chain-reaction-shattered-huge-antarctica-ice-shelf-1.13540', 0, 'Chain reaction shattered huge Antarctica ice shelf', 'worldnhistory', 0, '2013-08-13 13:35:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(135, 1, 'http://www.ted.com/talks/daphne_bavelier_your_brain_on_video_games.html', 0, 'TED Talks: Your Brain On Games', 'scintech', 0, '2013-08-13 13:37:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(136, 1, 'http://www.eweek.com/blogs/upfront/open-source-apache-web-server-hits-ignominious-milestone.html/', 0, 'Open-Source Apache Web Server Hits Ignominious Milestone', 'scintech', 0, '2013-08-13 13:38:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(137, 1, 'http://www.out.com/news-opinion/2013/08/02/men-who-want-aids-bronx-new-york?page=0,0', 0, 'The Men Who Want AIDSâ€”and How It Improved Their Lives', 'society', 0, '2013-08-13 15:11:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(138, 1, 'http://slashdot.org/topic/cloud/larry-ellison-believes-apple-is-doomed/', 0, 'Larry Ellison believes Apple is doomed', 'society', 0, '2013-08-13 16:11:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(139, 1, NULL, 0, NULL, NULL, 0, '2013-08-13 20:46:31', '0000-00-00 00:00:00', 0, 0, 0, 0, 0),
(140, 1, 'http://www.slate.com/blogs/behold/2013/08/13/anthony_s_karen_a_photojournalist_s_unrestricted_access_to_the_ku_klux_klan.html', 0, 'A day in the life of a Ku Klux Klan member', 'society', 0, '2013-08-13 22:06:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(141, 1, 'http://www.bloomberg.com/news/2013-08-11/ways-to-cut-the-cost-of-college.html', 0, 'Ways to cut the cost of college', 'society', 0, '2013-08-13 22:07:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(142, 1, 'http://www.youtube.com/watch?v=y2Eu_fUjNig', 0, 'Interview with Charles Manson (Serial Killer)', 'society', 0, '2013-08-14 05:27:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(143, 1, 'http://www.slate.com/blogs/crime/2013/08/13/israel_keyes_serial_killer_the_most_meticulous_serial_killer_of_modern_times.html', 0, 'The most meticulous serial killer of modern times', 'society', 0, '2013-08-15 16:20:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(144, 1, 'http://www.technologyreview.com/view/518301/new-form-of-carbon-is-stronger-than-graphene-and-diamond/', 0, 'Strongest material know to man', 'scintech', 0, '2013-08-15 16:21:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(145, 1, 'http://www.vice.com/read/drilling-a-hole-in-your-head-for-a-higher-state-of-consciousness', 0, 'Trepanation Lady', 'body', 0, '2013-08-15 16:22:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(146, 1, 'http://www.montrealgazette.com/news/changing+face+McGill+medical+students/8770876/story.html', 0, 'The changing face of McGill medical students', 'society', 0, '2013-08-16 00:06:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(147, 1, 'http://www.montrealgazette.com/news/Foreign+trained+being+shut/8789678/story.html?utm_source=dlvr.it&utm_medium=twitter', 0, 'Foreign-trained MDs being shut out', 'society', 0, '2013-08-16 00:07:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(148, 1, 'http://ca.finance.yahoo.com/news/8-ways-impress-boss-employee-135500114.html', 0, '8 Ways to Impress Your Boss As a New Employee', 'society', 0, '2013-08-16 19:21:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(149, 1, 'http://www.sunnewsnetwork.ca/sunnews/politics/archives/2013/08/20130816-174933.html', 0, 'NDP seeks answers on Senate residency rules', 'society', 0, '2013-08-16 23:00:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(150, 1, 'http://discovermagazine.com/2013/september/26-20-things-you-didnt-know-about-failure?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+DiscoverMag+%28Discover+Magazine%29#.UhDQopLqiSp', 0, '20 Things you didn\'t know about failure', 'society', 0, '2013-08-18 13:50:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(151, 1, 'http://www.theatlantic.com/politics/archive/2013/08/everything-you-think-you-know-about-government-fraud-is-wrong/278690/', 0, 'The Surprising Truth About Government Fraud', 'society', 0, '2013-08-18 13:50:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(152, 1, 'http://gawker.com/the-left-brain-right-brain-distinction-is-as-fake-as-it-1153790191?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed:+gawker/full+(Gawker)', 0, 'The Left-Brain-Right-Brain Distinction is as Fake as it Always Sounded', 'scintech', 0, '2013-08-18 13:52:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(153, 1, 'http://www.independent.co.uk/news/uk/home-news/slavery-in-the-city-death-of-21yearold-intern-moritz-erhardt-at-merrill-lynch-sparks-furore-over-long-hours-and-macho-culture-at-banks-8775917.html', 0, 'Death of 21-year-old intern Moritz Erhardt at Merrill Lynch sparks furore over long hours and macho culture at', 'society', 0, '2013-08-21 06:49:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(154, 1, 'http://www.wilsonquarterly.com/essays/still-god-helps-you?src=longreads', 0, 'Slavery Still Exists', 'society', 0, '2013-08-21 06:50:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(155, 1, 'http://www.thedailybeast.com/articles/2013/08/20/the-immortality-financiers-the-billionaires-who-want-to-live-forever.html', 0, 'The billionaires that want to live forever', 'scintech', 0, '2013-08-21 06:54:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(156, 1, 'http://www.businessweek.com/articles/2013-08-20/teslas-model-s-sedan-destroys-safety-tests-dot-dot-dot-literally', 0, 'Telsa\'s Model S Sedan Destroy\'s Safety Tests', 'scintech', 0, '2013-08-21 07:00:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(157, 1, 'http://thebillfold.com/2013/08/i-was-a-collegiate-lab-rat/', 0, 'I was a collegiate lab rat', 'scintech', 0, '2013-08-21 11:39:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(158, 1, 'http://www.newrepublic.com/article/114329/republican-budget-cut-would-crush-silicon-valley', 0, 'Republican budget cut would crush silicon valley', 'society', 0, '2013-08-21 12:16:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(159, 1, 'http://blogs.scientificamerican.com/beautiful-minds/2013/08/19/the-real-neuroscience-of-creativity/', 0, 'The real neuroscience of creativity', 'scintech', 0, '2013-08-21 13:06:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(160, 1, 'http://ca.screen.yahoo.com/top-10-worst-humans-time-132815026.html?vp=1', 0, '10 worst humans of all time', 'worldnhistory', 0, '2013-08-22 11:53:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(161, 1, 'http://motherboard.vice.com/blog/for-the-rest-of-the-year-humans-will-use-more-resources-than-the-earth-can-provide', 0, 'For the rest of days, people will use more resources than the earth can provide', 'worldnhistory', 0, '2013-08-22 14:35:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(162, 1, 'http://www.nature.com/news/big-horns-clash-with-longevity-in-sheep-1.13578', 0, 'Big horns clash with longevity in sheep', 'scintech', 0, '2013-08-23 17:51:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(163, 1, 'http://ideas.time.com/2013/08/25/the-internet-cannot-save-you/', 0, 'The internet cannot save you', 'society', 0, '2013-08-26 14:41:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(164, 1, 'http://www.androidbeat.com/2013/08/google-kills-chromecast-hacking/', 0, 'Google kills Chromecast hacking', 'scintech', 0, '2013-08-26 14:42:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(165, 1, 'http://www.nationaljournal.com/congress/could-www-vote-republican-be-a-porn-site-next-year-20130826', 0, 'Vote.Republican can be a porn site next year', 'society', 0, '2013-08-26 14:42:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(166, 1, 'http://www.bbc.co.uk/news/health-23811712', 0, 'Cocaine rapidly changes the structure of the brain', 'scintech', 0, '2013-08-26 14:43:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(167, 1, 'http://www.nypost.com/p/news/local/how_got_nyc_rich_kids_in_college_KQQVjQ2t4AFmy3UaFkvTDK', 0, 'Tutor reveals Ivy-admissions madness of rich penthouse parents', 'society', 0, '2013-08-26 14:47:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(168, 1, 'http://www.ctvnews.ca/world/zurich-opens-drive-in-sex-boxes-in-new-legal-prostitution-experiment-1.1427104', 0, 'Zurich opens drive-in \'sex boxes\' in new legal prostitution experiment', 'society', 0, '2013-08-26 17:38:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(169, 1, 'http://gawker.com/girl-finds-her-stolen-bike-on-craigslist-gets-it-back-1200971259', 0, 'Girl Finds Her Stolen Bike on Craigslist, Gets It Back By Being Amazing', 'society', 0, '2013-08-26 18:49:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(170, 1, 'http://www.economist.com/blogs/economist-explains/2013/08/economist-explains-11', 0, 'How can you buy illegal drugs online?', 'society', 0, '2013-08-27 01:08:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(171, 1, 'http://www.bloomberg.com/news/2013-08-26/three-charged-with-stealing-flow-traders-trading-software.html', 0, 'Three Charged With Stealing Flow Traders Trading Software', 'society', 0, '2013-08-27 01:51:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(172, 1, 'http://www.reuters.com/article/2013/08/26/us-goldman-options-leave-idUSBRE97P01620130826', 0, 'Goldman puts four on leave after fallout from trading glitch: report', 'society', 0, '2013-08-27 01:52:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(173, 1, 'http://ca.news.yahoo.com/mds-warned-watch-rare-form-abuse-parent-fabricated-040011431.html', 0, 'MDs warned to watch for rare form of abuse - parent-fabricated illness in kids', 'body', 0, '2013-08-27 03:48:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(174, 1, 'http://ca.news.yahoo.com/blogs/geekquinox/unearthed-peruvian-tomb-confirms-women-ruled-over-brutal-160013738.html', 0, 'Unearthed Peruvian tomb confirms that women ruled over brutal ancient culture', 'worldnhistory', 0, '2013-08-27 03:55:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(175, 1, 'http://www.nature.com/news/just-thinking-about-science-triggers-moral-behavior-1.13616', 0, 'Just thinking about science triggers moral behavior', 'scintech', 0, '2013-08-27 20:30:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(176, 1, 'http://www.washington.edu/news/2013/08/27/researcher-controls-colleagues-motions-in-1st-human-brain-to-brain-interface/', 0, 'Researcher controls colleagueâ€™s motions in 1st human brain-to-brain interface', 'scintech', 0, '2013-08-27 22:11:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(177, 1, 'http://www.torontosun.com/2013/08/28/chinese-boy-6-has-eyes-gouged-out-possibly-for-corneas', 0, 'Chinese boy, 6, has eyes gouged out, possibly for corneas', 'worldnhistory', 0, '2013-08-28 12:39:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(178, 1, 'http://www.vancouversun.com/health/pushed+improve+mental+health+services+reinstate+Riverview/8840197/story.html', 0, 'B.C. pushed to improve mental health services, reinstate Riverview Hospital', 'society', 0, '2013-08-28 12:40:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(179, 1, 'http://ca.news.yahoo.com/blogs/geekquinox/drug-offers-promise-exercise-pill-form-165247394.html', 0, 'Tantalizing new drug offers promise of exercise in pill form', 'scintech', 0, '2013-08-28 13:10:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(180, 1, 'http://www.bbc.co.uk/news/health-23870462', 0, 'Miniature \'human brain\' grown in laboratory', 'scintech', 0, '2013-08-29 00:13:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(181, 1, 'http://www.bbc.co.uk/news/science-environment-23872765', 0, 'Earth life \'may have come from Mars\'', 'scintech', 0, '2013-08-29 11:05:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(182, 1, 'http://www.dailymail.co.uk/news/article-2405374/Did-Kim-Jong-Un-execute-ex-girlfriend-making-sex-tape-North-Korean-leader-singer-shot-dozen-leading-musicians.html?ITO=1490&ns_mchannel=rss&ns_campaign=1490', 0, 'Did Kim Jong Un execute his ex-girlfriend for making a sex tape?', 'worldnhistory', 0, '2013-08-29 13:05:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(185, 1, 'http://www.nature.com/news/flu-vaccine-backfires-in-pigs-1.13621', 0, 'Flu vaccine backfires in pigs', 'scintech', 0, '2013-08-29 20:43:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(183, 1, 'http://www.telegraph.co.uk/women/womens-life/10272172/Why-do-girls-check-out-other-girls.html', 0, 'Why do girls check out other girls?', 'worldnhistory', 0, '2013-08-29 13:06:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(184, 1, 'http://ca.news.yahoo.com/blogs/pulseofcanada/justin-trudeau-setting-bad-example-kids-140132611.html', 0, 'Is Justin Trudeau setting a bad example for kids?', 'society', 0, '2013-08-29 13:20:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(186, 1, 'http://blogs.nature.com/news/2013/08/taiwan-court-set-to-decide-on-libel-case-against-scientist.html', 0, 'Taiwan court set to decide on libel case against scientist', 'society', 0, '2013-08-30 11:21:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(187, 1, 'http://www.calgaryherald.com/entertainment/Nearly+7000+Canadians+willing+give+life+know+join+Mars/8848209/story.html', 0, 'Nearly 7,000 Canadians willing to give up life as we know it join Mars One', 'society', 0, '2013-08-30 11:45:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(188, 1, 'http://theweek.com/article/index/248985/is-pot-now-essentially-legal-in-america', 0, 'Is pot now essentially legal in America?', 'society', 0, '2013-08-31 11:59:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(189, 1, 'http://www.businessinsider.com/the-weirdest-things-about-america-2013-8#ixzz2dhTZ2g1O', 0, 'The Most Surprising Things About America, According To An Indian International Student', 'society', 0, '2013-09-02 12:22:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(193, 1, 'http://imgur.com/gallery/G4BZf', 0, 'Dating tips for single ladies of 1938', 'worldnhistory', 0, '2013-09-02 21:30:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(190, 1, 'http://www.washingtonpost.com/blogs/wonkblog/wp/2013/08/29/do-presidents-really-reward-the-states-that-voted-them-into-office/?wprss=rss_ezra-klein&clsrd', 0, 'Do presidents really reward the states that voted them into office?', 'society', 0, '2013-09-02 12:24:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(191, 1, 'http://www.washingtonpost.com/blogs/wonkblog/wp/2013/08/30/the-tuition-is-too-damn-high-part-v-is-the-economy-forcing-colleges-to-spend-more/', 0, 'The Tuition is Too Damn High, Part V â€” Is the economy forcing colleges to spend more?', 'society', 0, '2013-09-02 12:25:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(192, 1, 'http://careerdare.com/5-jobs-that-pay-100k-a-year-without-a-degree/1/', 0, '5 Jobs That Pay 100k a Year Without a Degree', 'society', 0, '2013-09-02 12:33:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(194, 1, 'http://thinkprogress.org/justice/2013/08/30/2556291/neo-nazi-felon-stockpiling-guns/', 0, 'White Supremacist Felon Caught With 18 Guns, 45,000 Bullets And A List Of Black & Jewish Leaders', 'society', 0, '2013-09-03 01:52:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(195, 1, 'http://www.newrepublic.com/article/114505/anti-adoption-movement-next-reproductive-justice-frontier', 0, 'Meet the New Anti-Adoption Movement - The surprising next frontier in reproductive justice', 'society', 0, '2013-09-03 01:57:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(196, 1, 'http://www.bbc.co.uk/news/health-23932577', 0, 'Sleep \'boosts brain cell numbers\'', 'scintech', 0, '2013-09-05 01:22:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(197, 1, 'http://www.timescolonist.com/news/quebec-makes-a-change-to-landmark-7-daycare-system-1.613694', 0, 'Quebec makes a change to landmark $7 daycare system', 'society', 0, '2013-09-05 23:37:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(198, 1, 'http://www.nature.com/news/bacteria-from-lean-mice-prevents-obesity-in-peers-1.13693', 0, 'Bacteria from lean mice prevents obesity in peers', 'scintech', 0, '2013-09-06 16:14:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(199, 1, 'http://www.aeonmagazine.com/altered-states/would-dabbling-in-cranial-stimulation-make-me-smarter/', 0, 'I strapped TDCS electrodes to my head to see if I could make myself smarter by stimulating my brain. Hereâ€™s ', 'scintech', 0, '2013-09-07 12:51:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(200, 1, 'http://datamining.dongguk.ac.kr/work/Hyejoo/ref/birds%20of%20a%20feather-homophily.pdf', 0, 'People choose friends with similar DNA', 'scintech', 0, '2013-09-07 13:13:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(201, 1, 'https://medium.com/the-physics-arxiv-blog/2272bddcdb0d', 0, 'Humans Choose Friends With Similar DNA', 'scintech', 0, '2013-09-07 13:14:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(202, 1, 'http://arxiv.org/abs/1308.5257', 0, 'Friendship and Natural Selection', 'scintech', 0, '2013-09-07 13:17:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(203, 1, 'http://en.wikipedia.org/wiki/Rape_during_the_occupation_of_Germany', 0, 'Rape during the occupation of Germany', 'worldnhistory', 0, '2013-09-08 07:42:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(204, 1, 'http://www.businessinsider.com.au/geneticists-have-extended-the-lifespan-of-yeast-in-an-experiment-that-could-help-slow-human-ageing-2013-9', 0, 'New Research Could Slow Human Aging', 'scintech', 0, '2013-09-10 10:32:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(205, 1, 'http://www.narrative.ly/survivors/confessions-of-a-suicide-survivor/', 0, 'Confessions of a suicide survivor', 'society', 0, '2013-09-11 01:04:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(206, 1, 'http://modernfarmer.com/2013/09/starship-salad-bar/', 0, 'Nasa wants to start farming in space', 'scintech', 0, '2013-09-11 01:05:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(207, 1, 'http://videos.digg.com/post/61586340481/mike-tyson-is-freakishly-good-at-throwing-darts', 0, 'Mike Tyson Is Amazingly Good At Throwing Darts While Blind Folded', 'general', 0, '2013-09-18 14:53:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(208, 1, 'http://www.theguardian.com/news/datablog/interactive/2013/sep/17/us-gun-crime-map', 0, 'US Gun Crime Map', 'society', 0, '2013-09-18 14:54:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(209, 1, 'http://news.discovery.com/animals/zoo-animals/do-animals-cry-130917.htm#mkcpgn=rssnws1', 0, 'Do Animals Cry?', 'scintech', 0, '2013-09-18 14:55:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(210, 1, 'http://www.usatoday.com/story/tech/2013/09/17/google-cookies-advertising/2823183/', 0, 'Google May Ditch Cookies As Online Ad Trackers', 'scintech', 0, '2013-09-18 14:56:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(211, 1, 'http://motherboard.vice.com/blog/watch-a-millennium-of-european-history-at-internet-speed', 0, 'Watch A Millennium Of European History At Internet Speed', 'worldnhistory', 0, '2013-09-18 14:58:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(212, 1, 'http://www.washingtonpost.com/business/technology/obama-administration-urges-fcc-to-require-carriers-to-unlock-mobile-devices/2013/09/17/17b4917e-1fd4-11e3-b7d1-7153ad47b549_story.html', 0, 'Obama administration urges FCC to require carriers to unlock mobile devices', 'society', 0, '2013-09-18 15:06:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(213, 1, 'http://www.dzone.com/links/r/16_it_skills_in_high_demand_in_2013.html', 0, '16 IT Skills In High Demand 2013', 'scintech', 0, '2013-09-18 16:01:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(214, 1, 'http://news.sciencemag.org/brain-behavior/2013/09/naps-nurture-growing-brains', 0, 'Naps Nurture Growing Brain', 'scintech', 0, '2013-09-25 03:41:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(219, 1, 'http://www.patheos.com/blogs/inspiration/2013/04/life-is-not-fair/', 0, 'Life is not fair', 'society', 5, '2013-09-30 15:55:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(217, 1, 'http://www.kickstarter.com/projects/117421627/the-peachy-printer-the-first-100-3d-printer-and-sc', 0, 'Sub $100 3D Printer', 'scintech', 3, '2013-09-28 15:16:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(218, 1, 'http://www.huffingtonpost.com/helen-smith/8-reasons-men-dont-want-t_b_3467778.html', 0, '8 Reasons Straight Men Don\'t Want To Get Married', 'sexndating', 4, '2013-09-28 16:08:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(220, 1, 'http://www.businessinsider.com/dick-costolo-just-called-this-critic-of-his-all-male-all-white-board-the-carrot-top-of-academic-sources-2013-10', 0, 'Dick Costolo Just Called This Critic Of His All-Male, All-White Board \'The Carrot Top Of Academic Sources\' ', 'society', 6, '2013-10-10 00:51:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(221, 1, 'http://blogs.wsj.com/emergingeurope/2013/10/09/who-wants-to-be-a-russian-billionaire/', 0, 'Who wants to be a Russian billionaire?', 'society', 7, '2013-10-10 00:51:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(222, 1, 'http://www.nerve.com/love-sex/oof-it-looks-like-theres-a-happy-marriage-gene', 0, 'Looks like there may be a happy marriage gene', 'scintech', 8, '2013-10-10 00:51:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(223, 1, 'http://dkeats.com/index.php?module=blog&action=viewsingle&postid=gen21Srv8Nme0_40332_1381256759&userid=7050120123', 0, 'South African Education Department Bans Open Source Software', 'society', 0, '2013-10-10 00:52:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(224, 1, 'http://news.psu.edu/story/290471/2013/10/07/research/penn-state-lead-cyber-security-collaborative-research-alliance', 0, 'Army Wants Computer That Defends Against Human-Exploit Attacks', 'scintech', 0, '2013-10-10 05:27:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(225, 1, 'http://www.washingtonpost.com/blogs/worldviews/wp/2013/10/09/oops-azerbaijan-released-election-results-before-voting-had-even-started/', 0, 'Oops: Azerbaijan released election results before voting had even started', 'worldnhistory', 0, '2013-10-10 06:06:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(226, 1, 'http://www.nytimes.com/2013/10/11/business/blue-cross-plans-jump-to-an-early-lead.html?pagewanted=all&_r=0#!', 0, 'Blue Cross Plans Jump to an Early Lead', 'society', 0, '2013-10-12 01:48:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(227, 1, 'http://blogs.nature.com/news/2013/10/live-updates-us-government-shutdown.html', 0, 'Live updates: US government shutdown', 'society', 0, '2013-10-12 03:15:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(228, 1, 'http://www.cbsnews.com/8301-504083_162-57607907-504083/maryville-alleged-rape-special-prosecutor-requested-to-re-examine-mo-sexual-assault-case/', 0, 'Maryville Alleged Rape: Special prosecutor requested to re-examine Mo. sexual assault case', 'society', 0, '2013-10-18 00:00:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(229, 1, 'http://www.bbc.co.uk/news/magazine-24563590', 0, 'The problem with taking too many vitamins', 'body', 0, '2013-10-18 02:05:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(230, 1, 'http://www.atilus.com/what-does-a-website-cost-web-site-development-costs/', 0, 'Website Pricing: How Much Does A Website Cost?', 'scintech', 0, '2013-10-20 12:08:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(231, 1, 'http://blogs.smithsonianmag.com/science/2013/10/your-ethnicity-determines-the-species-of-bacteria-that-live-in-your-mouth/', 0, 'Your Ethnicity Determines the Species of Bacteria That Live in Your Mouth', 'body', 0, '2013-10-27 05:39:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0);
INSERT INTO `articlelinks` (`linkid`, `linktype`, `link`, `imageid`, `title`, `category`, `articleid`, `createdate`, `revisedate`, `voteup`, `votedown`, `voteinternal`, `creatorid`, `numcomments`) VALUES
(232, 1, 'http://www.cbc.ca/news/business/world-s-first-bitcoin-atm-goes-live-in-vancouver-next-week-1.2251820', 0, 'World\'s first Bitcoin ATM goes live in Vancouver next week', 'society', 0, '2013-10-27 05:40:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(233, 1, 'http://www.htxt.co.za/2013/10/24/inside-south-africas-first-textbook-free-government-school/', 0, 'Inside South Africaâ€™s first textbook free government school', 'society', 0, '2013-10-28 01:13:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(234, 1, 'http://www.slate.com/articles/business/billion_to_one/2013/10/sweden_s_billionaires_they_have_more_per_capita_than_the_united_states.html', 0, 'Why Does Sweden Have So Many Billionaires?', 'general', 0, '2013-11-02 11:11:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(235, 1, 'http://www.collectorsweekly.com/articles/how-romance-wrecked-traditional-marriage/', 0, 'Can\'t Buy Me Love: How Romance Wrecked Traditional Marriage', 'general', 0, '2013-11-02 13:03:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 1),
(236, 1, 'http://www.theatlantic.com/business/archive/2013/11/there-are-only-three-kinds-of-jobs-where-women-earn-more-than-men/281080/', 0, '3 Three Kinds of Jobs Where Women Earn More Than Men', 'society', 0, '2013-11-03 22:18:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(237, 1, 'http://www.theatlantic.com/business/archive/2013/11/the-workforce-is-even-more-divided-by-race-than-you-think/281175/', 0, 'The Workforce Is More Divided By Race Than You Think', 'society', 0, '2013-11-07 03:53:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(238, 1, 'http://motherboard.vice.com/blog/somehow-watching-porn-online-just-got-even-easier', 0, 'Watching Porn Online Just Got Easier', 'sexndating', 0, '2013-11-07 03:59:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(239, 1, 'http://www.theatlantic.com/business/archive/2013/11/the-33-whitest-jobs-in-america/281180/', 0, 'The 33 Whitest Jobs in America', 'society', 0, '2013-11-07 11:56:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(240, 1, 'http://vitaminl.tv/video/601?ref=rcm', 0, 'Awesome Action Movie in First-Person', 'cinema', 0, '2013-11-08 01:33:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(241, 1, 'http://www.theverge.com/2013/11/9/5084630/three-20-year-olds-build-their-own-version-of-healthcare-gov', 0, 'Three 20 Year Olds Built Their Own Version Of Healthcare.gov', 'general', 0, '2013-11-10 18:25:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(242, 1, 'http://io9.com/what-will-jail-terms-be-like-when-humans-can-live-for-c-1462281967?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+io9%2Ffull+%28io9%29', 0, 'What Will Jail Terms Be Like When Humans Can Live For Centuries', 'society', 0, '2013-11-12 01:52:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(243, 1, 'http://science.time.com/2013/11/13/the-sun-is-about-to-turn-upside-down-sort-of/', 0, 'The Sun is About to Turn Upside Down  Read more: The Sun Is About to Turn Upside Down!', 'scintech', 0, '2013-11-14 10:31:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(244, 1, 'http://www.nature.com/news/lyme-bacteria-show-that-evolvability-is-evolvable-1.14176', 0, 'Lyme bacteria show that evolvability is evolvable', 'general', 0, '2013-11-16 12:02:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(245, 1, 'http://www.coindesk.com/bitcoin-the-regulatory-story/?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+CoinDesk+%28CoinDesk+-+The+Voice+of+Digital+Currency%29&curator=MediaREDEF', 0, 'What Does The US Really Think About Bitcoins?', 'society', 0, '2013-11-16 17:12:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(246, 1, 'http://blogs.smithsonianmag.com/artscience/2013/11/do-our-brains-find-certain-shapes-more-attractive-than-others/', 0, 'Do Our Brains Find Certain Shapes More Attractive Than Others?', 'body', 0, '2013-11-16 17:17:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(247, 1, 'http://motherboard.vice.com/blog/will-giving-a-child-4000-make-them-smarter', 0, 'Will Giving a Child $4,000 Make Them Smarter?', 'society', 0, '2013-11-16 17:18:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(248, 1, 'http://ca.news.yahoo.com/exclusive-fbi-warns-u-government-breaches-anonymous-hackers-154054287--sector.html', 0, 'FBI warns of U.S. government breaches by Anonymous hackers', 'society', 0, '2013-11-16 19:56:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(249, 1, 'http://ca.news.yahoo.com/prosecutor-announcement-fatal-michigan-porch-shooting-120135846.html', 0, 'White Detroit-area man charged with murder of black woman', 'society', 0, '2013-11-16 19:58:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(250, 1, 'http://ca.news.yahoo.com/heinz-closes-leamington-plant-740-people-121227113.html', 0, 'Heinz closes Leamington plant, 740 people out of work', 'society', 0, '2013-11-16 19:59:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(251, 1, 'http://www.realclearscience.com/articles/2013/11/15/the_haunting_world_of_the_disease_detectives_108358.html', 0, 'The Haunting World of the Disease Detectives', 'scintech', 0, '2013-11-16 20:00:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(252, 1, 'http://www.radiosearchengine.com/', 0, 'Check out the world\'s first real time radio search engine', 'scintech', 0, '2013-11-16 20:02:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(253, 1, 'http://www.trueactivist.com/gab_gallery/fifty-people-one-question-what-is-your-biggest-regret/', 0, '50 People - What Is Your Biggest Regret?', 'society', 0, '2013-11-17 14:53:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(254, 1, 'http://www.buzzfeed.com/sandraeallen/i-was-drugged-by-a-stranger', 0, 'I was drugged by a stranger', 'society', 0, '2013-11-17 19:27:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(255, 1, 'http://www.brandonsun.com/national/breaking-news/one-whistleblowers-story-no-job-no-rent-no-recognition-no-redress-232262311.html?thx=y', 0, 'One whistleblower\'s story: no job, no rent, no recognition, no redress', 'society', 0, '2013-11-18 03:20:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(256, 1, 'http://www.bloomberg.com/news/2013-11-17/why-no-bankers-go-to-jail.html', 0, 'Why no bankers go to jail', 'society', 0, '2013-11-18 12:47:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(257, 1, 'http://www.nytimes.com/2013/11/16/world/europe/youth-unemployement-in-europe.html?=_r=6&_r=0', 0, 'Young and educated in europe, with no job', 'society', 0, '2013-11-18 12:47:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(258, 1, 'http://www.wired.com/threatlevel/2013/11/silk-road/', 0, 'How the feds took down the silk road wonderland', 'society', 0, '2013-11-18 12:49:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(259, 1, 'http://theweek.com/article/index/253227/this-electric-lollipop-can-simulate-any-taste', 0, 'Electric Lollipop Can Simulate Any Taste', 'scintech', 0, '2013-11-22 04:14:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(260, 1, 'http://www.todayifoundout.com/index.php/2013/11/parrots-name-chicks/', 0, 'Parrots Name Their Chicks', 'scintech', 0, '2013-11-22 05:44:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(261, 1, 'http://www.torontosun.com/2013/11/23/zumba-instructor-alexis-wright-released-from-prison-early', 0, 'Zumba instructor Alexis Wright released from prison early', 'society', 0, '2013-11-23 20:31:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(262, 1, 'http://www.theatlantic.com/education/archive/2013/11/japans-cutthroat-school-system-a-cautionary-tale-for-the-us/281612/', 0, 'Japan\'s Cut Throat Education System, A Tale For Us All', 'society', 0, '2013-11-24 01:39:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(263, 1, 'http://www.cbc.ca/news/health/krokodil-hype-is-toxic-flesh-eating-street-drug-in-canada-1.2435122', 0, 'Is a toxic \'flesh-eating\' street drug in Canada?', 'society', 0, '2013-11-25 12:29:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(264, 1, 'http://techcrunch.com/2013/11/23/lets-kill-the-aid-industry/?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+Techcrunch+%28TechCrunch%29', 0, 'Lets Kill The Aid Industry', 'society', 0, '2013-11-25 12:32:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(265, 1, 'http://www.gizmag.com/black-silicon-antibacterial-surface/29950/', 0, 'Black Silicon Kills Bacteria', 'scintech', 0, '2013-11-29 02:44:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(266, 1, 'http://valleywag.gawker.com/zuckerberg-wants-your-kids-student-data-1472766797', 0, 'Zuckerberg Wants Your Kid\'s Student Data', 'society', 0, '2013-11-29 02:47:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(267, 1, 'https://medium.com/the-physics-arxiv-blog/863c05238a41', 0, 'Poverty Escape Plan Revealed by Computer Model of Economic Vicious Cycles', 'society', 0, '2013-11-29 23:13:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(268, 1, 'http://dealbook.nytimes.com/2013/11/27/a-prediction-bitcoin-is-doomed-to-fail/?_r=0', 0, 'Why Bitcoin Is Doomed To Fail, In One Economist\'s Eyes', 'society', 0, '2013-11-29 23:16:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(269, 1, 'http://www.businessweek.com/articles/2013-11-27/how-poland-became-europes-most-dynamic-economy', 0, 'How Poland Became Europe\'s Most Dynamic Economy', 'society', 0, '2013-11-29 23:20:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(270, 1, 'http://abcnews.go.com/Technology/amazon-prime-air-delivery-drones-arrive-early-2015/story?id=21064960', 0, 'Amazon Prime Plans Using Air Delivery Drones', 'scintech', 0, '2013-12-02 06:45:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(271, 1, 'http://www.nature.com/news/fearful-memories-haunt-mouse-descendants-1.14272', 0, 'Experiences Are Passed Through Genetics', 'scintech', 0, '2013-12-03 02:21:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(272, 1, 'http://www2.macleans.ca/2013/12/02/an-anti-bully-intervention-gone-awry/', 0, 'An anti-bullying intervention gone awry', 'society', 0, '2013-12-03 04:02:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(273, 1, 'http://www.smithsonianmag.com/ideas-innovations/The-Toxins-That-Affected-Your-Great-Grandparents-Could-Be-In-Your-Genes-231152741.html#Skinner-ingenuity-birds-main-473.jpg', 0, 'Toxins That Affected Your Grandparents Can Be In Your Genes', 'scintech', 0, '2013-12-03 12:09:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(274, 1, 'http://www.businessweek.com/articles/2013-12-02/vitamin-c-infused-showers-do-they-work#r=hpt-ls', 0, 'Vitamin C Infused Showers, Do They Work?', 'body', 0, '2013-12-03 12:10:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(275, 1, 'http://usatoday30.usatoday.com/news/nation/mass-killings/index.html', 0, 'Behind The Bloodshed', 'society', 0, '2013-12-05 11:27:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(276, 1, 'http://ca.news.yahoo.com/nelson-mandela--revered-statesman-and-anti-apartheid-leader--dies-at-95-223333632.html', 0, 'Nelson Mandella Dies', 'society', 0, '2013-12-06 01:12:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(277, 1, 'http://www.wired.co.uk/magazine/archive/2013/12/ideas-bank/neurostimulation-is-the-next-mind-expanding-idea', 0, 'Neurostimulation - The Next Big Idea', 'scintech', 0, '2013-12-07 17:19:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(278, 1, 'http://www.thedailybeast.com/articles/2013/12/05/don-t-sanitize-nelson-mandela-he-s-honored-now-but-was-hated-then.html', 0, 'Donâ€™t Sanitize Nelson Mandela: Heâ€™s Honored Now, But Was Hated Then', 'society', 0, '2013-12-07 17:22:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(279, 1, 'http://www.nobelweekdialogue.org/2013/12/future-nuclear-power-let-thousand-flowers-bloom/', 0, 'The problem with the nuclear industry is that no one does it for fun anymore', 'scintech', 0, '2013-12-08 13:25:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(280, 1, 'http://www.michaelnielsen.org/ddi/how-the-bitcoin-protocol-actually-works/', 0, 'How the bitcoin protocol actually works', 'scintech', 0, '2013-12-08 13:26:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(281, 1, 'http://www.theguardian.com/science/2013/dec/06/peter-higgs-boson-academic-system', 0, 'Peter Higgs: I wouldn\'t be productive enough for today\'s academic system', 'society', 0, '2013-12-08 13:27:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(282, 1, 'http://www.nytimes.com/2013/12/09/world/asia/members-of-thai-opposition-party-quit-parliament.html?_r=0', 0, 'Members of Thai Opposition Party Quit Parliament', 'society', 0, '2013-12-08 18:09:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(283, 1, 'http://www.businessinsider.com/new-york-city-income-vs-shootings-map-2013-12', 0, 'Income vs Shootings', 'society', 0, '2013-12-08 18:09:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(284, 1, 'http://www.theguardian.com/technology/2013/dec/04/bitcoin-bubble-tulip-dutch-banker', 0, 'Bitcoin Hype Worse Than Tuple Mania', 'society', 0, '2013-12-08 18:46:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(285, 1, 'http://www.businessinsider.com/927-people-own-half-of-the-bitcoins-2013-12', 0, '927 People Own Half Of The Bitcoins', 'society', 0, '2013-12-11 12:05:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(286, 1, 'http://www.scientificamerican.com/article.cfm?id=rainbow-gravity-universe-beginning', 0, 'In a Rainbow Universe Time May Have No Beginning', 'scintech', 0, '2013-12-11 12:15:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(287, 1, 'http://projects.huffingtonpost.com/bryan-yeshion-schneps-one-knock-two-men-one-bullet', 0, 'One Knock. Two Men. One Bullet.', 'society', 0, '2013-12-13 11:48:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(288, 1, 'http://theweek.com/article/index/253953/millennial-women-have-seriously-narrowed-the-wage-gap-with-men', 0, 'Millennial women have seriously narrowed the wage gap with men', 'society', 0, '2013-12-13 11:50:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(289, 1, 'http://www.nerve.com/the-10-best-things-we-learned-from-a-strip-club-manager', 0, 'The 10 Best Things We Learned from a Strip Club Manager', 'society', 0, '2013-12-13 11:54:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(290, 1, 'http://qz.com/156507/how-to-date-online-like-a-social-scientist/', 0, 'How to date online like a social scientist', 'society', 0, '2013-12-14 12:09:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(291, 1, 'http://www.nature.com/news/simulations-back-up-theory-that-universe-is-a-hologram-1.14328', 0, 'Simulations back up theory that Universe is a hologram', 'scintech', 0, '2013-12-14 12:24:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(292, 1, 'http://theweek.com/article/index/253693/how-to-make-people-like-you-6-science-based-conversation-hacks', 0, 'How to make people like you', 'society', 0, '2013-12-14 12:53:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(293, 1, 'http://www.livescience.com/41898-alligators-crocodiles-use-tools.html', 0, 'Alligators and Crocodiles Use Tools to Hunt, in a First', 'scintech', 0, '2013-12-14 12:56:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(294, 1, 'http://ca.finance.yahoo.com/news/12-fast-growing-high-paying-192809719.html', 0, '12 Fast Growing Careers', 'society', 0, '2013-12-15 12:22:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(295, 1, 'http://ca.news.yahoo.com/chinese-lunar-probe-lands-moon-report-132351891.html', 0, 'Chinese unmanned spacecraft lands on moon', 'scintech', 0, '2013-12-15 12:41:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(296, 1, 'http://www.bbc.com/future/story/20131212-smart-drugs-at-work-good-idea/all', 0, 'Would you take smart drugs to perform better at work?', 'society', 0, '2013-12-15 13:03:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(297, 1, 'http://blog.metrotrends.org/2013/12/criminals-guns/', 0, 'Where do criminals get guns?', 'society', 0, '2013-12-15 13:05:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(298, 1, 'http://www.newsweek.com/dirty-money-makes-world-go-round-224344', 0, 'Dirty Money Makes The World Go Round', 'society', 0, '2013-12-15 13:12:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(299, 1, 'http://www.dailydot.com/lifestyle/wireless-router-wi-fi-plants/', 0, 'Wireless May Kill House Plants', 'scintech', 0, '2013-12-18 01:57:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(300, 1, 'http://well.blogs.nytimes.com/2013/12/16/three-biological-parents-and-a-baby/?src=recg&_r=0', 0, 'The girl with 3 parents', 'scintech', 0, '2013-12-18 12:00:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(301, 1, 'http://healthland.time.com/2013/12/16/researchers-reveal-the-microscopic-reasons-why-pets-protect-against-allergies/?xid=rss-topstories&utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+time%2Ftopstories+%28TIME%3A+Top+Stories%29', 0, 'Why do pets protect against allergies?', 'society', 0, '2013-12-18 12:01:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(302, 1, 'http://thebillfold.com/2013/12/when-new-jersey-boosted-its-minimum-wage-20-years-ago/', 0, 'When New Jersey Boosted Its Minimum Wage 20 Years Ago', 'society', 0, '2013-12-18 12:08:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(303, 1, 'http://www.thedailybeast.com/witw/articles/2013/12/16/should-birth-control-sabotage-be-considered-a-crime.html', 0, 'Should Birth Control Sabotage Be Considered a Crime?', 'society', 0, '2013-12-18 12:29:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(304, 1, 'http://digg.com/video/tim-cook-talks-about-being-discriminated-as-a-gay-man', 0, 'Tim Cook Talks About Being Discriminated As A Gay Man', 'society', 0, '2013-12-18 12:32:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(305, 1, 'http://www.psfk.com/2013/12/self-cleaning-plates.html#!qaQxl', 0, 'Self Cleaning Plates Make Doing Dishes A Thing Of The Past', 'scintech', 0, '2013-12-19 12:58:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(306, 1, 'http://www.popsci.com/article/technology/can-human-fall-love-computer?dom=PSC&loc=recent&lnk=3&con=can-a-human-fall-in-love-with-a-computer', 0, 'Can a human fall in love with a computer?', 'society', 0, '2013-12-19 12:59:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 1),
(307, 1, 'http://www.theatlantic.com/business/archive/2013/12/the-south-is-americas-high-school-dropout-factory/282480/', 0, 'America\'s Educational Attainment Mapped', 'society', 0, '2013-12-19 13:00:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(308, 1, 'http://www.nature.com/nature/journal/vaop/ncurrent/full/nature12886.html', 0, 'The complete genome sequence of a Neanderthal from the Altai Mountains', 'scintech', 0, '2013-12-20 02:58:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(309, 1, 'http://www.newyorker.com/online/blogs/currency/2013/12/handsome-ceos-handsome-returns.html', 0, 'DOES BEAUTY DRIVE ECONOMIC SUCCESS?', 'society', 0, '2013-12-21 11:49:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(310, 1, 'http://blogs.wsj.com/digits/2013/12/19/data-broker-removes-rape-victims-list-after-journal-inquiry/', 0, 'Data Broker Removes Rape-Victims List After Journal Inquiry', 'society', 0, '2013-12-21 12:17:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(311, 1, 'http://www.abc.net.au/news/2013-12-20/scientists-develop-anti-ageing-process-in-mice/5168580', 0, 'Scientists reverse ageing in mice, humans could be next', 'scintech', 0, '2013-12-21 12:22:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(312, 1, 'http://www.news24.com/Technology/News/Metamaterials-Other-benefits-besides-invisibility-20131226', 0, 'Metamaterials: Other benefits besides invisibility', 'scintech', 0, '2013-12-26 19:19:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(313, 1, 'http://www.medpagetoday.com/InfectiousDisease/GeneralInfectiousDisease/43583', 0, 'CDC Warns of New Virus Threat in Caribbean', 'worldnhistory', 0, '2013-12-26 19:19:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(314, 1, 'http://talkingpointsmemo.com/cafe/everything-you-think-you-know-about-gangs-is-wrong', 0, 'Everything You Think You Know About Gangs Is Wrong', 'society', 0, '2013-12-26 19:22:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(315, 1, 'http://www.youtube.com/watch?v=nsVJ8p1UPc8', 0, 'Ted Bundy - Final Interview', 'society', 0, '2013-12-26 20:32:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(316, 1, 'http://ca.askmen.com/entertainment/austin/keep-your-friends-close.html', 0, 'The Reason You\'ll Probably Loose Friends As You Age', 'society', 0, '2013-12-28 12:17:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(317, 1, 'http://www.dailydot.com/business/what-happens-dead-bitcoin-wallet/', 0, 'What happens to dead bitcoins?', 'scintech', 0, '2013-12-28 12:28:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(318, 1, 'http://thebillfold.com/2013/01/i-need-to-do-everything-in-my-power-not-to-be-poor/', 0, 'I Need to Do Everything in My Power Not to Be Poor', 'society', 0, '2013-12-28 12:36:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(319, 1, 'http://www.cbc.ca/news/technology/blackberry-faces-another-year-of-uncertainty-1.2478003', 0, 'BlackBerry Faces Another Year Of Uncertainty', 'society', 0, '2013-12-29 05:02:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(320, 1, 'http://www.nytimes.com/2013/12/29/science/brainlike-computers-learning-from-experience.html?=_r=6&', 0, 'Brain like computers learning from experience', 'scintech', 0, '2013-12-29 15:58:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(321, 1, 'http://listdose.com/top-10-reasons-why-people-fail-in-life/', 0, 'Top 10 reasons people fail in life', 'society', 0, '2013-12-29 15:59:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(322, 1, 'http://www.brainpickings.org/index.php/2012/11/20/daily-routines-writers/', 0, 'The Daily Routines of Famous Writers', 'society', 0, '2013-12-30 05:39:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(323, 1, 'http://www.telegraph.co.uk/technology/10540341/The-Oculus-Rift-virtual-reality-is-no-longer-a-joke.html', 0, 'Virtual Reality Is No Longer A Joke', 'scintech', 0, '2013-12-30 05:41:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(324, 1, 'http://www.computerworld.com/s/article/9245050/Chromebooks_success_punches_Microsoft_in_the_gut', 0, 'Chromebooks\' success punches Microsoft in the gut', 'society', 0, '2013-12-30 07:07:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(325, 1, 'http://www.independent.co.uk/news/science/video-sun-has-flipped-upside-down-as-new-magnetic-cycle-begins-9029378.html', 0, 'The Sun\'s Magnetic Field Has Flipped', 'scintech', 0, '2013-12-30 07:10:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(326, 1, 'http://www.redorbit.com/news/health/1113035923/aids-research-fraud-iowa-state-university-122713/', 0, 'Iowa State AIDS Researcher Admits To Falsifying Study Findings, Fraud', 'society', 0, '2013-12-30 07:11:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(327, 1, 'https://medium.com/the-physics-arxiv-blog/bfc25f2ffe03', 0, 'Neural Net Learns Breakout Then Thrashes Human Gamers', 'scintech', 0, '2013-12-30 07:14:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(328, 1, 'http://www.bloomberg.com/news/2013-12-29/france-s-hollande-gets-court-approval-for-75-millionaire-tax.html', 0, 'France gives approval for 75% millionaire tax', 'society', 0, '2013-12-31 00:24:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(329, 1, 'http://talkingpointsmemo.com/news/retirement-crisis-great-recession', 0, 'The World Braces For A Retirement Crisis', 'society', 0, '2013-12-31 02:48:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(330, 1, 'http://www.nytimes.com/2013/12/31/science/i-had-my-dna-picture-taken-with-varying-results.html?_r=0', 0, 'I Had My DNA Picture Taken, With Varying Results', 'scintech', 0, '2013-12-31 04:22:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(331, 1, 'http://www.forbes.com/sites/daviddisalvo/2012/08/18/why-jerks-get-ahead/', 0, 'Why Jerks Get Ahead', 'society', 0, '2013-12-31 04:40:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(332, 1, 'http://thesiswhisperer.com/2013/02/13/academic-assholes/', 0, 'Academic assholes and the circle of niceness', 'society', 0, '2013-12-31 04:44:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(333, 1, 'http://www.bbc.com/future/story/20131219-can-astronauts-cook-fries', 0, 'What would french fries taste like if you made them on Jupiter?', 'scintech', 0, '2013-12-31 05:27:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(334, 1, 'http://motherboard.vice.com/blog/the-japanese-mob-is-hiring-homeless-people-to-clean-up-fukushima', 0, 'The Japanese Mob is hiring homeless people to work inside Fukushima', 'society', 0, '2013-12-31 12:14:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(335, 1, 'http://www.computerworld.com/s/article/9244923/The_firm_behind_Healthcare.gov_had_top_notch_credentials_and_it_didn_t_help', 0, 'The firm behind Healthcare.gov had top-notch credentials -- and it didn\'t help', 'society', 0, '2013-12-31 12:14:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(336, 1, 'http://www.theguardian.com/environment/2013/dec/31/planet-will-warm-4c-2100-climate', 0, 'Planet likely to warm by 4C by 2100, scientists warn', 'scintech', 0, '2014-01-01 16:48:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(337, 1, 'http://www.bbc.co.uk/news/magazine-25549805', 0, 'Intermittent Fasting: The Good Things It Did To My Body', 'scintech', 0, '2014-01-04 13:28:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(338, 1, 'http://news.discovery.com/tech/alternative-power-sources/students-walking-smart-hallway-help-power-school-140104.htm#mkcpgn=rssnws1', 0, 'These Students Power Their School Just By Walking Down Its Hallways', 'scintech', 0, '2014-01-05 00:13:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(339, 1, 'https://www.hackthis.co.uk/articles/picking-locks-a-basic-guide', 0, 'Lock Picking - A Basic Guide', 'scintech', 9, '2014-01-06 12:13:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(340, 1, 'https://www.simonsfoundation.org/quanta/20140102-a-missing-genetic-link-in-human-evolution/', 0, 'A Missing Genetic Link in Human Evolution', 'scintech', 0, '2014-01-07 13:04:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(341, 1, 'http://online.wsj.com/news/articles/SB10001424052702304213904579095303368899132', 0, 'Why Tough Teachers Get Good Results', 'society', 0, '2014-01-09 04:10:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(342, 1, 'http://www.cbsnews.com/news/police-boy-12-opens-fire-in-nm-school-seriously-injuring-2/', 0, 'POLICE: NM SCHOOL SHOOTER IS 12-YEAR-OLD BOY', 'society', 0, '2014-01-15 11:42:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(343, 1, 'http://www.foxnews.com/us/2014/01/15/man-charged-in-florida-movie-theater-shooting-over-texting-had-praiseworthy/', 0, 'Man charged in Florida movie theater shooting over texting had praiseworthy police career', 'society', 0, '2014-01-15 11:43:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(344, 1, 'http://www.heavy.com/news/2014/01/chad-olsen-florida-movie-theater-shooting-curtis-reeves/', 0, 'Chad Oulson: 5 Fast Facts You Need to Know ', 'society', 0, '2014-01-15 11:46:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(347, 1, 'http://www.wired.com/wiredscience/2014/01/how-to-hack-okcupid/', 0, 'How to hack OKCupid', 'sexndating', 0, '2014-01-22 08:07:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(345, 1, 'http://www.vocativ.com/video/colombian-cocaine-factory/', 0, 'The house that cocaine built', 'society', 0, '2014-01-15 11:54:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(346, 1, 'http://www.computerworld.com/s/article/9245494/What_STEM_shortage_Electrical_engineering_lost_35_000_jobs_last_year', 0, 'What STEM shortage? Electrical engineering lost 35,000 jobs last year', 'scintech', 0, '2014-01-17 12:37:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(348, 1, 'http://blog.penelopetrunk.com/2006/04/16/dont-be-the-hardest-worker-in-your-job-or-in-your-job-hunt/', 0, 'Donâ€™t be the hardest worker in your job or in your job hunt', 'society', 0, '2014-01-25 18:09:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(349, 1, 'http://www.nature.com/news/stephen-hawking-there-are-no-black-holes-1.14583', 0, 'There are no black holes', 'scintech', 0, '2014-01-25 20:39:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(350, 1, 'http://techcrunch.com/2014/01/27/samsung-said-to-be-planning-galaxy-glass-computing-eyeware-this-fall/', 0, 'Samsung Said To Be Planning â€˜Galaxy Glassâ€™ Computing Eyeware This Fall', 'scintech', 0, '2014-01-28 01:42:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(351, 1, 'http://venturebeat.com/2014/01/29/california-regulator-seeks-to-shut-down-learn-to-code-bootcamps/', 0, 'California regulator seeks to shut down â€˜learn to codeâ€™ bootcamps', 'society', 0, '2014-01-31 12:19:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(352, 1, 'http://www.nature.com/news/first-monkeys-with-customized-mutations-born-1.14611', 0, 'First monkeys with customized mutations born', 'scintech', 0, '2014-02-03 04:53:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(353, 1, 'http://www.salon.com/2014/02/07/the_history_white_people_need_to_learn/', 0, 'Why Isn\'t There A White History Month?', 'worldnhistory', 0, '2014-02-07 10:59:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 2),
(354, 1, 'http://ca.news.yahoo.com/video/panhandlers-kicked-groin-cash-012300567.html', 0, 'Pan Handler Kicked In Groin For Cash', 'society', 0, '2014-02-07 10:59:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(355, 1, 'http://fcw.com/articles/2014/02/05/nasa-has-significant-problems-with-2b-it-contract.aspx', 0, 'NASA has \'significant problems\' with $2.5B IT contract', 'society', 0, '2014-02-08 11:00:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(356, 1, 'http://www.itnews.com.au/News/371774,russia-bans-bitcoin.aspx', 0, 'Russia bans Bitcoin', 'scintech', 0, '2014-02-08 11:02:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(357, 1, 'http://www.independent.co.uk/news/world/asia/thailand-protests-pm-yingluck-shinawatra-ploughs-on-despite-calls-for-her-to-stand-down-after-disputed-election-9117082.html', 0, 'PM Yingluck Shinawatra ploughs on despite calls for her to stand down ', 'society', 10, '2014-02-09 00:49:16', '0000-00-00 00:00:00', 0, 0, 0, 85, 0),
(358, 1, 'http://news.nationalpost.com/2014/02/23/liberals-vote-to-legalize-assisted-suicide-at-partys-national-convention/', 0, 'Liberals vote to legalize assisted suicide at partyâ€™s national convention', 'society', 0, '2014-02-24 00:54:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(359, 1, 'http://www.cbc.ca/news/canada/toronto/john-tory-karen-stintz-both-to-run-for-toronto-mayor-1.2548812', 0, 'John Tory, Karen Stintz both to run for Toronto mayor', 'society', 0, '2014-02-24 09:39:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(360, 1, 'http://www.bbc.co.uk/news/world-africa-26320102', 0, 'Ugandan President Museveni \'to sign\' anti-gay bill', 'society', 0, '2014-02-24 09:39:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(361, 1, 'http://www.youtube.com/watch?v=Uj56IPJOqWE', 0, 'Indian Headshakes | What do they mean?', 'society', 0, '2014-02-24 09:46:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(362, 1, 'http://pando.com/2014/02/23/called-to-account-a-suicide-bombing-a-lawsuit-a-bank-accused-of-financing-terrorism/', 0, 'Follow the blood money: Exposing the secret US banking operations that help fund suicide bombers', 'society', 0, '2014-02-24 09:49:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(363, 1, 'http://www.nature.com/news/einstein-s-lost-theory-uncovered-1.14767', 0, 'Einsteinâ€™s lost theory uncovered', 'scintech', 0, '2014-02-25 11:08:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(364, 1, 'http://techcrunch.com/2014/02/28/whats-not-being-said-about-bitcoin/', 0, 'What\'s Not Being Said About Bitcoin', 'scintech', 0, '2014-03-02 02:20:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(365, 1, 'http://www.nytimes.com/2014/03/06/education/major-changes-in-sat-announced-by-college-board.html?hp&_r=2', 0, 'A New SAT Aims To Realign With Schoolwork', 'society', 0, '2014-03-06 04:24:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(366, 1, 'http://news.discovery.com/animals/strange-state-of-matter-found-in-chicken-eye-140301.htm', 0, 'Strange State of Matter Found in Chicken\'s Eye', 'scintech', 0, '2014-03-06 11:05:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(367, 1, 'http://www.psmag.com/navigation/books-and-culture/prison-education-programs-worth-75796/', 0, 'Are Prison Education Programs Worth It?', 'society', 0, '2014-03-06 11:56:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(368, 1, 'http://www.nytimes.com/2014/03/06/health/second-success-raises-hope-for-a-way-to-rid-babies-of-hiv.html?hp&_r=0', 0, '2nd Baby Cured Of HIV', 'scintech', 0, '2014-03-06 11:58:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(369, 1, 'http://www.ecanadanow.com/health/2014/03/08/report-links-teenage-energy-drinks-with-substance-abuse/', 0, 'REPORT LINKS TEENAGE ENERGY DRINKS WITH SUBSTANCE ABUSE', 'society', 0, '2014-03-08 19:57:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(370, 1, 'http://www.reuters.com/article/2014/03/06/us-genomics-future-analysis-idUSBREA2527520140306', 0, 'The dawning of the age of genomic medicine, finally', 'scintech', 0, '2014-03-08 20:19:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(371, 1, 'http://www.bbc.com/news/health-26480756', 0, 'Blood test can predict Alzheimer\'s, say researchers', 'scintech', 0, '2014-03-10 01:00:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(372, 1, 'http://guardianlv.com/2014/03/freed-30-year-death-row-inmate-shows-dangerous-flaws-in-death-penalty/', 0, 'Freed 30 Year Death Row Victim', 'society', 0, '2014-03-13 10:20:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(373, 1, 'http://www.cbsnews.com/news/danger-still-lurks-in-bangladesh-garment-factories/', 0, 'Danger still lurks in Bangladesh garment factories', 'society', 0, '2014-03-13 10:22:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(374, 1, 'http://www.slate.com/articles/health_and_science/medical_examiner/2014/03/physician_shortage_should_we_shorten_medical_education.html', 0, 'Should It Really Take 14 Years to Become a Doctor?', 'society', 0, '2014-03-14 04:31:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(375, 1, 'http://www.dailymail.co.uk/femail/article-1205387/Would-date-ugly-man.html', 0, 'Would you date an ugly man?', 'sexndating', 0, '2014-03-14 05:29:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(376, 1, 'http://www.slate.com/blogs/xx_factor/2014/03/13/urban_institute_sex_work_study_pimps_sex_workers_child_pornographers_and.html', 0, 'Pimps are attempting a rebranding', 'society', 0, '2014-03-16 14:26:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(377, 1, 'http://www.bostonglobe.com/ideas/2014/03/15/the-poor-neglected-gifted-child/rJpv8G4oeawWBBvXVtZyFM/story.html', 0, 'Early developers tend to perform better as adults', 'body', 0, '2014-03-16 14:26:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(378, 1, 'http://www.nature.com/news/diminutive-dinosaur-stalked-the-arctic-1.14859', 0, 'Diminutive dinosaur stalked the Arctic', 'scintech', 0, '2014-03-16 14:28:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(379, 1, 'http://www.newrepublic.com/article/117007/while-west-watches-crimea-putin-cleans-house-moscow', 0, 'While the West Watches Crimea, Putin Cleans House in Moscow', 'society', 0, '2014-03-16 14:29:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(380, 1, 'http://www.thedailybeast.com/articles/2014/03/13/thanks-anti-vaxxers-you-just-brought-back-measles-in-nyc.html', 0, 'Thanks, Anti-Vaxxers. You Just Brought Back Measles in NYC.', 'society', 0, '2014-03-16 14:30:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(381, 1, 'http://www.nerve.com/love-sex/everything-we-know-so-far-about-drug-resistant-gonorrhea', 0, 'Everything we know about drug resistant Gonorrhea', 'scintech', 0, '2014-03-16 14:41:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(382, 1, 'http://www.theglobeandmail.com/news/toronto/three-arrested-in-alleged-16-million-fraud-scheme-at-york-university/article17590694/', 0, 'Three arrested in alleged $1.6-million fraud at York University', 'society', 0, '2014-03-21 11:32:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(383, 1, 'http://www.thespec.com/news-story/4424277-province-moves-to-halt-pay-for-plasma-clinics/', 0, 'Province moves to halt pay-for-plasma clinics', 'scintech', 0, '2014-03-21 11:33:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(384, 1, 'https://www.computerworld.com.au/article/540930/h-1b_visas_produce_net_it_job_boost/', 0, 'H-1B visas produce net IT job boost', 'society', 0, '2014-03-22 12:26:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(385, 1, 'http://edition.cnn.com/2014/03/24/politics/obama-europe-trip/', 0, 'U.S., other powers kick Russia out of G8', 'worldnhistory', 0, '2014-03-25 11:25:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(386, 1, 'http://www.nbcnews.com/science/science-news/medical-first-3-d-printed-skull-successfully-implanted-woman-n65576', 0, '3-D Printed Skull Successfully Implanted in Woman', 'scintech', 0, '2014-03-28 11:21:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(387, 1, 'http://www.buzzfeed.com/emilyorley/being-raped-in-a-bankrupt-city', 0, 'Being Raped In A Bankrupt City', 'society', 0, '2014-03-28 11:26:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(388, 1, 'http://www.fastcoexist.com/3028012/this-edible-blob-is-a-water-bottle-without-the-plastic', 0, 'This blob is something you can eat and drink all in one go', 'scintech', 0, '2014-03-28 11:29:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(389, 1, 'http://theweek.com/article/index/258896/how-to-flirt-according-to-science', 0, 'How to flirt, according to science', 'sexndating', 0, '2014-03-30 04:40:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(390, 1, 'http://www.theguardian.com/technology/2014/apr/01/mind-controlled-robotic-suit-exoskeleton-world-cup-2014', 0, 'Mind-controlled robotic suit to debut at World Cup 2014', 'scintech', 0, '2014-04-02 11:45:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(391, 1, 'http://arstechnica.com/science/2014/04/a-new-microbe-might-have-accelerated-the-great-dying/?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+arstechnica%2Findex+%28Ars+Technica+-+All+content%29', 0, 'A new microbe might have accelerated the Great Dying', 'society', 0, '2014-04-02 11:46:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(392, 1, 'http://www.slate.com/articles/life/family/2014/04/new_robert_faris_study_popular_kids_go_after_each_other_for_social_status.html', 0, 'High-status kids go after each other more than they go after misfits', 'society', 0, '2014-04-02 11:47:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(393, 1, 'http://www.newrepublic.com/article/117233/unfair-restaurant-tipping-research-shows-it-rewards-blondes', 0, 'The Tipping System Is Biased', 'society', 0, '2014-04-03 11:14:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(394, 1, 'http://www.theverge.com/2014/4/2/5570866/cortana-windows-phone-8-1-digital-assistant', 0, 'Windows Phone 8.1 Digital Assistant', 'scintech', 0, '2014-04-03 11:28:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(395, 1, 'http://www.theglobeandmail.com/report-on-business/economy/currencies/bitcoin-believers-why-digital-currency-backers-are-keeping-the-faith/article17840246/', 0, 'Bitcoin believers: Why digital currency backers are keeping the faith', 'scintech', 0, '2014-04-05 12:32:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(396, 1, 'http://www.ctvnews.ca/canada/report-warns-pancake-syrups-in-u-s-may-cause-cancer-1.1760873', 0, 'Report warns pancake syrups in U.S. may cause cancer', 'society', 0, '2014-04-05 12:36:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(397, 1, 'http://elitedaily.com/life/motivation/simple-experiement-explains-human-condition/', 0, 'This Simple Experiment With Monkeys Perfectly Explains How Society Holds Us Back', 'society', 0, '2014-04-11 01:11:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(398, 1, 'http://www.nature.com/news/ancient-mars-probably-too-cold-for-liquid-water-1.15042', 0, 'Ancient Mars probably too cold for liquid water', 'scintech', 0, '2014-04-15 07:41:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(399, 1, 'http://www.bbc.com/news/technology-27052773', 0, 'Cyborg glasses save users the need to control emotions', 'scintech', 0, '2014-04-20 01:58:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(400, 1, 'https://medium.com/p/58a20c16fefa', 0, 'The Puzzle of Iapetus and the Mountains That Fell From Space', 'scintech', 0, '2014-04-20 01:59:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(401, 1, 'http://www.nature.com/news/sperm-rna-carries-marks-of-trauma-1.15049', 0, 'Sperm RNA carries marks of trauma', 'scintech', 0, '2014-04-20 02:00:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(402, 1, 'http://io9.com/these-tests-can-prove-whether-you-are-in-the-fourth-dim-1558992280?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+io9%2Ffull+%28io9%29', 0, 'These Tests Can Prove Whether You Are in the Fourth Dimension', 'scintech', 0, '2014-04-20 02:02:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(403, 1, 'http://www.cracked.com/article_19219_the-7-craziest-things-ever-done-to-get-laid.html', 0, 'The 7 Craziest Things Ever Done to Get Laid', 'society', 0, '2014-04-20 02:16:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(404, 1, 'http://www.wired.com/2014/04/xapo/', 0, 'The World\'s First Bitcoin Debit Card Is Almost Here', 'scintech', 0, '2014-04-27 01:09:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(405, 1, 'http://www.salon.com/2014/04/26/the_worlds_newest_mineral_is_unlike_anything_weve_ever_seen_before_partner/', 0, 'Putnisite - The World\'s Newest Mineral', 'scintech', 0, '2014-04-27 01:32:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(406, 1, 'http://www.montrealgazette.com/news/world/China+orders+Bang+Theory+Good+Wife+other+shows+streaming/9780808/story.html', 0, 'China orders \'The Big Bang Theory,\' \'The Good Wife,\' other US shows off streaming sites', 'society', 0, '2014-04-27 13:41:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(407, 1, 'http://www.torontosun.com/2014/05/01/missing-canadian-journalist-filmmaker-found-dead-in-cambodia', 0, 'Missing Canadian journalist, filmmaker found dead in Cambodia', 'society', 0, '2014-05-03 00:14:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(408, 1, 'http://www.theglobeandmail.com/globe-debate/were-hooked-on-foreign-workers/article18348408/', 0, 'Weâ€™re hooked on foreign workers', 'society', 0, '2014-05-03 00:15:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(409, 1, 'http://www.independent.co.uk/news/uk/this-britain/revelation-666-is-not-the-number-of-the-beast-its-a-devilish-616-526779.html', 0, 'Revelation! 666 is not the number of the beast (it\'s a devilish 616)', 'society', 0, '2014-05-03 10:44:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(410, 1, 'http://www.theatlantic.com/politics/archive/2014/05/the-man-who-integrated-the-white-house-press-corps/361599/', 0, 'The Man Who Integrated The White House Press Corps', 'society', 0, '2014-05-03 20:33:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(411, 1, 'http://kottke.org/14/05/a-splash-of-seawater', 0, 'A splash of seawater', 'scintech', 0, '2014-05-05 03:45:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(412, 1, 'http://www.theglobeandmail.com/news/world/recovered-videos-of-final-minutes-show-students-panic-and-fear-as-ferry-sunk/article18359046/', 0, 'Recovered videos of final minutes on board ferry show studentsâ€™ panic and fear', 'society', 0, '2014-05-05 03:46:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(413, 1, 'http://www.torontosun.com/2014/05/01/missing-canadian-journalist-filmmaker-found-dead-in-cambodia', 0, 'Missing Canadian journalist, filmmaker found dead in Cambodia', 'society', 0, '2014-05-05 03:47:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(414, 1, 'http://www.theglobeandmail.com/globe-debate/were-hooked-on-foreign-workers/article18348408/', 0, 'Weâ€™re hooked on foreign workers', 'society', 0, '2014-05-05 03:48:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(415, 1, 'http://www.montrealgazette.com/health/rodents+react+differently+male+researchers+than+female/9784080/story.html', 0, 'Lab rodents react differently to male researchers than female', 'scintech', 0, '2014-05-05 03:49:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(416, 1, 'http://www.vancouversun.com/health/resurges+child+after+stopping+medication+soon+call+treatment+babies+cure/9804995/story.html', 0, 'HIV resurges in child after stopping medication; too soon to call treatment in babies a â€˜cureâ€™', 'scintech', 0, '2014-05-05 03:52:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(417, 1, 'http://www.citifmonline.com/2014/05/uganda-to-criminalize-willful-hiv-transmission/', 0, 'Uganda to criminalize â€˜willfulâ€™ HIV transmission', 'society', 0, '2014-05-05 04:03:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(418, 1, 'http://www.washingtonpost.com/blogs/wonkblog/wp/2014/05/03/which-groups-do-criminals-target-not-who-you-might-think/', 0, 'Which groups do criminals target?', 'society', 0, '2014-05-05 10:29:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(419, 1, 'http://www.nytimes.com/2014/05/05/science/young-blood-may-hold-key-to-reversing-aging.html?_r=0', 0, 'Young Blood', 'scintech', 0, '2014-05-05 10:31:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(420, 1, 'http://theconversation.com/humans-and-squid-evolved-same-eyes-using-same-genes-26265', 0, 'Humans and Squid Evolved Using The Same Gene', 'society', 0, '2014-05-07 11:29:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(421, 1, 'http://www.calgaryherald.com/health/Electric+probes+will+allow+take+control+your+dreams/9830672/story.html', 0, 'Electric probes will allow you to take control of your dreams', 'scintech', 0, '2014-05-13 07:30:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(422, 1, 'http://www.vox.com/2014/5/13/5714650/russia-just-evicted-nasa-from-the-international-space-station', 0, 'Russia is kicking NASA out of the International Space Station in 2020', 'scintech', 0, '2014-05-14 08:44:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(423, 1, 'http://online.wsj.com/news/articles/SB10001424052702304655304579551974194329920', 0, 'Poll Says Anti-Semitism Is Global Matter', 'society', 0, '2014-05-14 08:47:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(424, 1, 'http://www.newyorker.com/online/blogs/newsdesk/2014/05/how-the-fbi-cracked-a-chinese-spy-ring.html', 0, 'How the F.B.I. cracked a chinese spy ring', 'society', 0, '2014-05-18 22:26:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(425, 1, 'http://digg.com/2014/the-female-sociopath', 0, 'The Female Sociopath', 'society', 0, '2014-05-18 22:28:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(426, 1, 'http://timesofindia.indiatimes.com/World/US/North-Korea-labels-President-Obama-a-cross-breed-black-monkey-in-racist-attack/articleshow/34890224.cms', 0, 'North Korea labels President Obama a \'cross-breed black monkey\' in racist attack', 'society', 0, '2014-05-18 22:29:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(427, 1, 'http://www.cbc.ca/news/world/nigeria-schoolgirls-could-be-traded-for-prisoners-report-says-1.2635884', 0, 'Nigeria schoolgirls could be traded for prisoners', 'society', 0, '2014-05-18 22:30:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(428, 1, 'http://www.theguardian.com/world/2013/dec/31/victorian-police-act-against-racial-bias-but-say-racism-is-not-systemic', 0, 'Victorian police act against racial bias but say racism is not systemic', 'society', 0, '2014-05-18 22:53:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(429, 1, 'http://www.thedailybeast.com/articles/2014/05/17/how-pfizer-helped-make-spice-the-deadly-fake-pot.html', 0, 'How Pfizer Helped Make â€˜Spice,â€™ The Deadly Fake Pot', 'society', 0, '2014-05-19 02:24:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(430, 1, 'http://www.pbs.org/newshour/making-sense/will-rich-always-get-richer/', 0, 'Will the rich always get richer?', 'society', 0, '2014-05-19 02:24:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(431, 1, 'http://scienceblog.com/72485/study-debunks-common-myth-urine-sterile/?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+scienceblogrssfeed+%28ScienceBlog.com%29', 0, 'Study debunks common myth that urine is sterile', 'scintech', 0, '2014-05-19 15:04:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(432, 1, 'http://articles.philly.com/2014-05-18/news/49928236_1_birgeneau-haverford-students-haverford-college', 0, 'Haverford College commencement speaker lambastes students', 'society', 0, '2014-05-19 15:05:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(433, 1, 'https://ca.shine.yahoo.com/blogs/healthy-living/theres-good-chance-hpv-dont-realize-215700611.html', 0, 'There\'s a Good Chance You Have HPV and Don\'t Realize It', 'body', 0, '2014-05-22 10:41:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(434, 1, 'http://www.cbc.ca/news/canada/toronto/toronto-surgeons-could-make-history-with-canada-s-1st-hand-transplant-1.2652946', 0, 'Toronto surgeons could make history with Canada\'s 1st hand transplant', 'scintech', 0, '2014-05-24 04:25:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(435, 1, 'http://www.houstonchronicle.com/nasa/adrift/1/', 0, 'As NASA seeks next mission, Russia holds the trump card', 'scintech', 0, '2014-05-24 04:29:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(436, 1, 'http://www.chicagomag.com/Chicago-Magazine/June-2014/Chicago-crime-statistics/', 0, 'The Truth About Chicagoâ€™s Crime Rates', 'society', 0, '2014-05-24 04:29:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(437, 1, 'http://www.policymic.com/articles/89679/why-so-many-rock-stars-die-at-27-explained-by-science', 0, 'Why So Many Rock Stars Die at 27, Explained by Science', 'society', 0, '2014-05-24 04:30:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(438, 1, 'http://www.vox.com/2014/5/21/5723452/could-more-price-transparency-in-health-care-really-save-100-billion', 0, 'Solving the mystery of health-care prices could save $100 billion', 'society', 0, '2014-05-24 04:31:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(439, 1, 'http://www.slate.com/articles/life/education/2014/05/why_professors_inflate_grades_because_their_jobs_depend_on_it.html', 0, 'Confessions of a Grade Inflator', 'society', 0, '2014-05-24 04:33:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(440, 1, 'http://news.nationalpost.com/2014/05/05/i-abducted-your-girls-boko-haram-reportedly-takes-responsibility-for-kidnapping-nigerian-schoolgirls/', 0, 'â€˜I will sell them in the marketplaceâ€™: Boko Haram leader threatens to sell kidnapped Nigerian schoolgirls', 'society', 0, '2014-05-24 04:34:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(441, 1, 'http://www.therecord.com/news-story/4537061-password-s-days-numbered-security-experts-say/', 0, 'Passwordâ€™s days numbered, security experts say', 'scintech', 0, '2014-05-24 23:54:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(442, 1, 'http://www.iflscience.com/chemistry/teen-threatened-graduation-ban-yearbook-quote', 0, 'Teen Threatened With Graduation Ban For Yearbook', 'society', 0, '2014-05-25 15:44:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0);
INSERT INTO `articlelinks` (`linkid`, `linktype`, `link`, `imageid`, `title`, `category`, `articleid`, `createdate`, `revisedate`, `voteup`, `votedown`, `voteinternal`, `creatorid`, `numcomments`) VALUES
(443, 1, 'http://mashable.com/2014/05/25/elliot-rodger-profile/', 0, 'Elliot Rodger: Portrait of a Lonely Outcast Obsessed With Status', 'society', 0, '2014-05-25 23:37:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(444, 1, 'http://www.newrepublic.com/article/117884/nicholas-wades-troublesome-inheritance-new-scientific-racism', 0, 'The Dangerous New Scientific Racism', 'scintech', 0, '2014-05-25 23:43:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(445, 1, 'http://theweek.com/article/index/262000/even-making-college-free-wouldnt-reduce-americas-wealth-gap', 0, 'Even making college free wouldn\'t reduce America\'s wealth gap', 'society', 0, '2014-05-26 09:50:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(446, 1, 'http://nymag.com/daily/intelligencer/2014/05/three-bodies-found-in-elliot-rodgers-home.html', 0, 'Bodies of Three Men Found in Elliot Rodger\'s Home as More Details of Santa Barbara Shooter\'s Life Emerge', 'general', 0, '2014-05-26 10:02:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(447, 1, 'http://www.nytimes.com/2014/05/26/world/middleeast/pope-francis-west-bank.html?hp&_r=0', 0, 'Pope Openly Endorses \'The State Of Palestine\'', 'society', 0, '2014-05-26 10:06:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(448, 1, 'http://motherboard.vice.com/read/understanding-alien-messages-may-be-no-different-than-decoding-the-rosetta-stone', 0, 'Understanding Alien Messages May Be No Different Than Decoding the Rosetta Stone', 'scintech', 0, '2014-05-26 10:16:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(449, 1, 'http://www.vox.com/2014/5/24/5742178/why-half-of-college-graduates-are-invisible-to-the-federal-government', 0, 'The college graduation rate is flawed â€” and hard to fix', 'society', 0, '2014-05-26 10:19:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(450, 1, 'http://abcnews.go.com/Business/wireStory/shopping-future-23842573?singlePage=true', 0, 'What Shopping Will Look Like in the Future', 'society', 0, '2014-05-26 10:21:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(451, 1, 'http://canadajournal.net/health/junk-food-linked-preterm-birth-risk-study-8859-2014/', 0, 'Junk Food Linked to Preterm Birth Risk', 'body', 0, '2014-05-27 10:31:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(452, 1, 'http://www.pbs.org/newshour/updates/google-discloses-workforce-diversity-data-good/', 0, 'Google finally discloses its diversity record, and itâ€™s not good', 'society', 0, '2014-05-29 09:26:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(453, 1, 'https://ca.news.yahoo.com/blogs/canada-politics/former-stephen-harper-colleagues-dish-temper-170251993.html', 0, 'Former Stephen Harper colleagues give a peek into prime minister\'s temper', 'society', 0, '2014-05-29 09:27:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(454, 1, 'http://thinkprogress.org/economy/2014/05/27/3441772/florida-homeless-financial-study/', 0, 'Leaving Homeless Person On The Streets: $31,065. Giving Them Housing: $10,051', 'society', 0, '2014-05-29 09:48:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(455, 1, 'http://www.washingtonpost.com/blogs/federal-eye/wp/2014/05/28/ig-report-confirms-allegations-at-phoenix-va-hospital/', 0, 'Inspector generalâ€™s report confirms allegations at Phoenix VA hospital', 'society', 0, '2014-05-29 09:50:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(456, 1, 'http://www.newrepublic.com/article/117928/wwii-photography-blitz-england-people-wearing-gas-masks', 0, 'Kids Playing in Gas Masks and Other Spooky Photos from World War II', 'worldnhistory', 0, '2014-05-29 09:51:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(457, 1, 'http://www.slate.com/blogs/xx_factor/2014/05/28/slut_shaming_and_class_a_study_on_how_college_women_decide_who_s_trashy.html', 0, 'Are You a Slut? That Depends. Are You Rich?', 'society', 0, '2014-05-29 10:42:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(458, 1, 'http://cnews.canoe.ca/CNEWS/Canada/2014/05/28/21702136.html', 0, 'Middle class, not rich, reap most from Harper tax cuts', 'society', 0, '2014-05-29 10:44:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(459, 1, 'http://www.telegraph.co.uk/news/worldnews/northamerica/usa/10861781/Edward-Snowden-I-can-sleep-at-night-and-I-have-done-the-right-thing.html', 0, 'Edward Snowden: I can sleep at night and I have done the right thing', 'society', 0, '2014-05-29 10:45:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(460, 1, 'http://globalnews.ca/news/1362949/be-careful-what-you-write-that-online-review-could-get-you-sued/', 0, 'Be careful what you write: that online review could get you sued', 'society', 0, '2014-05-30 09:21:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(461, 1, 'http://www.theglobeandmail.com/news/british-columbia/heroin-prescriptions-for-addicts-okayed-in-court-ordered-injunction/article18913042/', 0, 'Court rules to allow patients to continue supervised heroin use', 'society', 0, '2014-05-30 10:12:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(462, 1, 'https://ca.finance.yahoo.com/news/the-32-words-that-used-incorrectly-can-make-you-look-bad-161319699.html', 0, 'The 32 Words That Used Incorrectly Can Make You Look Bad', 'society', 0, '2014-06-02 11:19:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(463, 1, 'https://ca.finance.yahoo.com/news/17-tips-quickly-paying-down-191300858.html', 0, '17 tips on debt repayment from a guy who paid off $74,000 in 2 years', 'society', 0, '2014-06-02 11:49:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(464, 1, 'http://www.buzzfeed.com/catesevilla/35-things-only-people-who-work-weird-hours-will-understand?bffb', 0, '35 Things Only People Who Work Weird Hours Will Understand', 'society', 0, '2014-06-04 10:46:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(465, 1, 'http://www.q107.com/2014/06/03/what-makes-men-attractive-to-women/', 0, 'What Makes Men Attractive To Women', 'sexndating', 0, '2014-06-04 10:49:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(466, 1, 'http://www.independent.co.uk/news/world/americas/the-slender-man-what-you-need-to-know-9483602.html', 0, 'The Slender Man: What you need to know', 'society', 0, '2014-06-04 10:53:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(467, 1, 'http://www.nature.com/nature/journal/vaop/ncurrent/full/nature13347.html', 0, 'Population health: Immaturity in the gut microbial community', 'society', 0, '2014-06-05 10:40:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(468, 1, 'http://money.cnn.com/2014/06/04/news/economy/american-dream/index.html', 0, 'The American Dream is out of reach', 'society', 0, '2014-06-05 10:46:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(469, 1, 'http://www.theverge.com/2014/6/4/5779198/if-violence-is-in-your-genes-should-courts-be-more-lenient', 0, 'If violence is in your genes, should courts be more lenient?', 'society', 0, '2014-06-05 10:47:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(470, 1, 'http://www.washingtonpost.com/posteverything/wp/2014/06/04/the-science-of-sexuality-how-our-genes-make-us-gay-or-straight/', 0, 'Scientists just found the gene that makes us gay or straight', 'scintech', 0, '2014-06-05 10:51:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(471, 1, 'http://priceonomics.com/extreme-poverty-has-dropped-in-half-since-1990/', 0, 'Extreme Poverty Has Dropped in Half Since 1990', 'worldnhistory', 0, '2014-06-06 09:56:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(472, 1, 'http://www.core77.com/blog/materials/life_imitates_art_the_bacteriographical_art_of_zachary_copfer__27047.asp', 0, 'Bacteria Cultivated Portrates', 'scintech', 0, '2014-06-06 09:57:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(473, 1, 'http://www.thewire.com/technology/2014/06/50-cent-is-now-accepting-bitcoin/372139/', 0, '50 Cent Is Now Accepting Bitcoin', 'society', 0, '2014-06-06 09:57:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(474, 1, 'http://www.citynews.ca/2014/06/06/8-charged-in-toronto-human-trafficking-case/', 0, '8 charged in Toronto human trafficking case', 'society', 0, '2014-06-07 11:52:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(475, 1, 'http://www.thestar.com/news/city_hall/2014/06/07/rob_ford_adrift_without_an_ethical_compass_james.html', 0, 'Rob Ford adrift without an ethical compass', 'society', 0, '2014-06-07 11:52:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(476, 1, 'http://gizmodo.com/soviet-doctors-cured-infections-with-viruses-and-soon-1587311881', 0, 'Soviet Doctors Cured Infections With Viruses, and Soon Yours Might Too', 'scintech', 0, '2014-06-08 11:57:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(477, 1, 'http://www.bbc.com/news/blogs-magazine-monitor-27734048', 0, 'The prevailing myth of sex before sport', 'body', 0, '2014-06-08 11:58:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(478, 1, 'http://www.theguardian.com/lifeandstyle/poll/2014/jun/06/sleep-memory-discovered-scientists-how-much-enough?CMP=twt_gu', 0, 'Sleep\'s role in memory formation discovered: do you get enough?', 'body', 0, '2014-06-08 11:58:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(479, 1, 'http://www.salon.com/2014/06/07/the_one_thing_neil_degrasse_tyson_got_wrong/', 0, 'The one thing Neil deGrasse Tyson got wrong', 'society', 0, '2014-06-08 12:00:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(480, 1, 'http://lifehacker.com/master-the-art-of-small-talk-with-strangers-to-be-happ-1587103408?utm_campaign=socialflow_lifehacker_twitter&utm_source=lifehacker_twitter&utm_medium=socialflow', 0, 'Master the Art of Small Talk with Strangers to Be Happier', 'society', 0, '2014-06-08 12:00:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(481, 1, 'http://www.psmag.com/navigation/nature-and-technology/statistically-significant-studies-arent-necessarily-significant-82832/', 0, 'Why Statistically Significant Studies Arenâ€™t Necessarily Significant', 'scintech', 0, '2014-06-08 12:01:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(482, 1, 'http://timesofindia.indiatimes.com/world/rest-of-world/Raping-makes-us-feel-free-DR-Congos-soldiers-reveal-astonishing-stories/articleshow/36253376.cms', 0, 'â€˜Raping makes us feel freeâ€™: DR Congoâ€™s soldiers reveal astonishing stories', 'society', 0, '2014-06-08 14:29:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(483, 1, 'http://www.newyorker.com/online/blogs/joshuarothman/2014/06/fixing-the-phd.html', 0, 'FIXING THE PH.D.', 'society', 0, '2014-06-08 14:59:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(484, 1, 'http://www.wired.com/2014/06/rats-regret-making-the-wrong-decision/', 0, 'Rats Regret Making the Wrong Decision', 'scintech', 0, '2014-06-09 02:21:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(485, 1, 'http://abcnews.go.com/International/wireStory/bergdahl-tortured-taliban-captors-24045272?singlePage=true', 0, 'Bergdahl Says He Was Tortured by Taliban Captors', 'worldnhistory', 0, '2014-06-09 02:25:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(486, 1, 'http://www.motherjones.com/media/2014/06/street-harassment-survey-america', 0, 'Now We Know How Many Women Get Groped by Men in Public', 'society', 0, '2014-06-10 00:22:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(487, 1, 'http://jalopnik.com/tesla-motors-all-our-patents-are-belong-to-you-1589971589', 0, 'Tesla Will \'Open-Source\' All Its Patents', 'society', 0, '2014-06-13 10:15:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(488, 1, 'http://www.bostonglobe.com/business/2014/06/12/retiring-couples-face-health-care-costs-says-study/Ass4It8FRpelmv0tI9nDfI/story.html', 0, 'Retiring couples face $220k in health care costs, study says', 'society', 0, '2014-06-13 10:15:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(489, 1, 'http://www.businessweek.com/articles/2014-06-11/heres-why-the-student-loan-market-is-completely-insane', 0, 'Here\'s Why the Student Loan Market Is Completely Insane', 'society', 0, '2014-06-13 10:16:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(490, 1, 'http://www.nature.com/news/origins-of-arctic-fox-traced-back-to-tibet-1.15398', 0, 'Origins of Arctic fox traced back to Tibet', 'scintech', 0, '2014-06-13 10:17:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(491, 1, 'http://www.bbc.com/news/science-environment-27812367', 0, 'Crayfish may experience form of anxiety', 'scintech', 0, '2014-06-14 04:43:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(492, 1, 'http://www.esquire.com/blogs/news/downsides-of-being-a-dad', 0, 'THE DOWNSIDES OF BEING A DAD', 'sexndating', 0, '2014-06-14 04:43:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(493, 1, 'http://nymag.com/scienceofus/2014/06/kids-not-do-drugs-chill-out.html', 0, 'If You Donâ€™t Want Your Kids to Do Drugs, Chill Out a Bit', 'society', 0, '2014-06-14 04:43:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(494, 1, 'http://www.theguardian.com/science/2014/jun/13/earth-may-have-underground-ocean-three-times-that-on-surface', 0, 'Earth may have underground \'ocean\' three times that on surface', 'scintech', 0, '2014-06-14 04:48:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(495, 1, 'http://inventors.about.com/library/inventors/blpen.htm', 0, 'History of the Pencil and Pen', 'scintech', 0, '2014-06-14 15:23:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(496, 1, 'http://www.nature.com/news/dinosaurs-neither-warm-blooded-nor-cold-blooded-1.15399', 0, 'Dinosaurs neither warm-blooded nor cold-blooded', 'scintech', 0, '2014-06-14 15:53:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(497, 1, 'https://www.youtube.com/watch?v=mKzwquG3G5k', 0, 'New Ninja Turtles Trailer', 'cinema', 0, '2014-06-14 15:54:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(498, 1, 'http://www.theguardian.com/law/2014/jun/13/jail-someone-for-being-offensive-twitter-facebook', 0, 'Is it right to jail someone for being offensive on Facebook or Twitter?', 'society', 0, '2014-06-15 08:54:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(499, 1, 'http://earthweareone.com/what-a-shaman-sees-in-a-mental-hospital/', 0, 'What a Shaman Sees in A Mental Hospital', 'body', 0, '2014-06-15 08:59:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(500, 1, 'http://themindunleashed.org/2014/04/car-runs-100-years-without-refuelling-thorium-car.html', 0, 'This Car Runs For 100 Years Without Refuelling â€“ The Thorium Car', 'scintech', 0, '2014-06-21 12:12:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(501, 1, 'http://www.buzzfeed.com/steveknopper/how-joe-dorsey-knocked-out-segregation', 0, 'How Joe Dorsey Knocked Out Segregation', 'worldnhistory', 0, '2014-06-21 21:49:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(502, 1, 'http://www.businessinsider.com/riot-games-pays-employees-25000-to-quit-2014-6', 0, 'This Company Pays Employees $25,000 To Quit â€” No Strings Attached - Even If They Were Just Hired', 'society', 0, '2014-06-21 22:36:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(503, 1, 'http://minorities.affordablehealthinsurance.org/2013/02/study-denver-doctors-nurses-racial-bias-black-patients101.html#.U60fSPnGAeo', 0, 'Racist Doctors? New Study Shows 66% of Doctors (And Nurses) Are Racially Biased Towards Their Black Patients', 'society', 0, '2014-06-27 07:38:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(504, 1, 'http://takingnote.blogs.nytimes.com/2014/06/25/what-are-you-really-worth-to-your-employer/?_php=true&_type=blogs&_r=0', 0, 'What are you really worth to your employer?', 'society', 0, '2014-06-28 04:07:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(505, 1, 'http://www.nydailynews.com/life-style/temporary-tattoo-unlocks-moto-x-article-1.1846778', 0, 'Ink that links to your phone?', 'scintech', 0, '2014-06-28 04:13:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(506, 1, 'http://www.roadtovr.com/google-adds-virtual-reality-street-view-mode-to-google-maps-for-android/', 0, 'Cheap VR Technology From Google', 'scintech', 0, '2014-06-30 11:24:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(507, 1, 'http://www.itworld.com/it-management/425046/california-law-removes-ban-alternative-currencies', 0, 'California Removes Ban on Alternate Currencies', 'scintech', 0, '2014-06-30 11:25:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(508, 1, 'http://gawker.com/who-you-love-is-a-political-choice-1596978900?utm_source=feedburner&utm_medium=feed&utm_campaign=Feed%3A+gawker%2Ffull+%28Gawker%29', 0, 'Who you love is a political choice', 'society', 0, '2014-06-30 11:29:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(509, 1, 'http://www.washingtonpost.com/opinions/when-lincoln-saved-the-union-and-freed-the-slaves-five-ex-presidents-tried-to-stop-him/2014/06/27/21de5d80-f0ba-11e3-9ebc-2ee6f81ed217_story.html', 0, 'When Lincoln saved the union and freed the slaves, five ex-presidents tried to stop him', 'worldnhistory', 0, '2014-06-30 11:34:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(510, 1, 'http://www.youtube.com/watch?v=XjJQBjWYDTs#t=37', 0, 'Like a Girl', 'society', 0, '2014-06-30 11:38:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(511, 1, 'http://www.vox.com/2014/6/27/5845484/prisons-are-terrible-and-there-is-finally-a-way-to-get-rid-of-them', 0, 'An Alternative to Prison', 'society', 0, '2014-06-30 11:39:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(512, 1, 'http://www.nytimes.com/2014/06/29/upshot/americans-think-we-have-the-worlds-best-colleges-we-dont.html?rref=upshot&module=ArrowsNav&contentCollection=The%20Upshot&action=swipe&region=FixedLeft&pgtype=article', 0, 'Americans think we have the world\'s best colleges. We don\'t.', 'society', 0, '2014-06-30 11:40:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(513, 1, 'http://boss.blogs.nytimes.com/2014/06/30/when-a-20-year-employee-becomes-a-problem/?_php=true&_type=blogs&partner=yahoofinance&_r=0', 0, 'When a 20 year old employee becomes a problem', 'society', 0, '2014-07-01 09:39:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(514, 1, 'http://www.cbc.ca/news/health/mixed-race-babies-with-asian-dads-are-born-smaller-1.2693364', 0, 'Mixed-race babies with Asian dads are born smaller', 'scintech', 0, '2014-07-02 09:55:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(515, 1, 'http://www.timescolonist.com/sports/b-c-school-districts-to-show-teachers-summer-classes-that-must-be-held-1.1189954', 0, 'B.C. school districts to show teachers summer classes that must be held', 'society', 0, '2014-07-02 09:59:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(516, 1, 'http://www.telegraph.co.uk/news/worldnews/middleeast/syria/10939235/Rome-will-be-conquered-next-says-leader-of-Islamic-State.html', 0, 'Rome will be conquered next, says leader of \'Islamic State\'', 'society', 0, '2014-07-02 10:25:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(517, 1, 'http://www.dailystar.com.lb/News/World/2014/Jul-02/262356-sarkozy-detained-in-french-corruption-investigation.ashx#axzz36J1lYKCe', 0, 'Sarkozy detained in French corruption investigation', 'worldnhistory', 0, '2014-07-02 10:31:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(518, 1, 'http://www.addedbytes.com/articles/writing-secure-php/', 0, 'Writing Secure PHP', 'scintech', 0, '2014-07-03 11:05:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(519, 1, 'http://www.telegraph.co.uk/science/space/10955749/Where-has-all-the-light-in-the-universe-gone.html', 0, 'Where has all the light in the universe gone?', 'scintech', 0, '2014-07-11 03:12:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(520, 1, 'http://www.washingtonpost.com/news/morning-mix/wp/2014/07/10/scholarly-journal-retracts-60-articles-smashes-peer-review-ring/', 0, 'Scholarly journal retracts 60 articles, smashes â€˜peer review ringâ€™', 'society', 0, '2014-07-11 12:04:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(521, 1, 'http://www.vox.com/2014/7/12/5891451/meet-the-medical-student-who-wants-to-bring-down-dr-oz-quackery', 0, 'Meet the medical student who wants to bring down Dr. Oz', 'society', 0, '2014-07-13 18:13:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(522, 1, 'http://www.independent.co.uk/news/science/blackest-is-the-new-black-scientists-have-developed-a-material-so-dark-that-you-cant-see-it-9602504.html', 0, 'Scientists have developed a material so dark that you can\'t see it', 'scintech', 0, '2014-07-13 22:56:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(523, 1, 'http://www.washingtonpost.com/blogs/wonkblog/wp/2014/07/11/college-graduates-are-sorting-themselves-into-cities-increasingly-out-of-reach-of-everyone-else/', 0, 'A â€˜nationwide gentrification effectâ€™ is segregating us by education', 'society', 0, '2014-07-14 10:46:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(524, 1, 'http://www.space.com/26635-underwater-neemo-18-mission.html', 0, 'Astronauts Simulate Deep-Space Mission in Underwater Lab For 8 Days', 'scintech', 11, '2014-07-28 00:50:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(525, 1, 'http://www.newyorker.com/magazine/2014/08/04/crime-fiction', 0, 'Did the Chicago police coerce witnesses into pinpointing the wrong man for murder?', 'society', 12, '2014-07-29 12:00:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(526, 1, 'http://time.com/3042640/satellite-russian-ukraine-shelling/', 0, 'U.S: Satellite Imagery Shows Russians Shelling Eastern Ukraine', 'worldnhistory', 13, '2014-07-29 12:00:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(527, 1, 'http://ninjasandrobots.com/why-are-some-people-so-much-luckier-than-others', 0, 'Why are some people so much luckier than others?', 'society', 14, '2014-07-30 03:19:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(528, 1, 'http://www.theroot.com/blogs/the_grapevine/2014/08/_iftheygunnedmedown_shows_how_black_people_are_portrayed_in_mainstream_media.html', 0, 'How Black People Are Portrayed in Mainstream Media', 'society', 15, '2014-08-12 10:50:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(529, 1, 'http://www.cnn.com/2014/08/09/justice/charles-manson-wife', 0, 'Charles Manson\'s wife', 'society', 16, '2014-08-12 10:50:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(530, 1, 'http://boingboing.net/2014/08/15/inside-job.html', 0, 'Secret Polish Army', 'worldnhistory', 17, '2014-08-16 23:26:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(531, 1, 'http://www.kyivpost.com/opinion/op-ed/is-ukraine-racist-or-not-1-128529.html', 0, 'Is Ukraine racist or not?', 'society', 0, '2014-08-31 11:16:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(532, 1, 'http://www.pri.org/stories/2014-09-14/singles-now-outnumber-married-people-america-and-thats-good-thing', 0, 'Singles now outnumber married people in America â€” and that\'s a good thing', 'society', 0, '2014-09-15 06:37:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(533, 1, 'http://scienceline.org/2007/06/ask-dricoll-inuiteskimos/', 0, ' Inuits live in very cold climates, why do they have dark skin?', 'scintech', 0, '2014-09-22 00:43:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(534, 1, 'http://www.ipolitics.ca/2013/06/28/harper-government-reduces-employment-equity-requirements-for-contractors/', 0, 'Harper government reduces employment equity requirements for contractors', 'society', 18, '2014-09-30 04:52:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(535, 1, 'http://www.washingtonpost.com/blogs/wonkblog/wp/2014/10/18/poor-kids-who-do-everything-right-dont-do-better-than-rich-kids-who-do-everything-wrong/', 0, 'Poor kids who do everything right donâ€™t do better than rich kids who do everything wrong', 'society', 0, '2014-10-20 00:50:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(536, 1, 'http://www.nbcwashington.com/news/local/Hannah-Graham-Human-Remains-Found-During-Search--279678342.html', 0, 'Poor kids who do everything right donâ€™t do better than rich kids who do everything wrong', 'society', 0, '2014-10-20 02:00:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(537, 1, 'http://njbw.businessweek.com/articles/2014-10-27/politicians-really-cant-create-jobs', 0, 'Politicians Can\'t Create Jobs', 'society', 0, '2014-10-28 08:48:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(538, 1, 'https://www.minds.com/blog/view/282282199510683648/whistleblower-reveals-how-big-pharma-corps-profit-from-lifelong-disease', 0, 'Whistleblower reveals how big pharma corps profit from lifelong disease', 'society', 0, '2014-10-28 08:49:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(539, 1, 'https://ca.news.yahoo.com/ebola-discrimination-senegal-kids-nyc-bronx-105520236.html', 0, 'As Ebola fears spread, children allegedly bullied for West African ties', 'society', 0, '2014-10-29 07:14:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(540, 1, 'https://ca.news.yahoo.com/woman-intellectual-disability-sexually-assaulted-232046870.html', 0, 'Woman with intellectual disability sexually assaulted on bus as support worker sat nearby', 'society', 0, '2014-10-29 07:16:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(541, 1, 'http://www.girlschase.com/content/how-make-and-find-female-friends', 0, 'How to Make and Find Female Friends', 'society', 0, '2014-10-29 09:34:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(542, 1, 'https://ca.news.yahoo.com/swedens-government-recognizes-state-palestine-100726643.html', 0, 'Sweden Recognizes Palestine', 'general', 0, '2014-10-31 11:35:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(543, 1, 'http://www.theaustralian.com.au/news/world/canada-joins-australia-in-restricting-visas-amid-ebola-scare/story-e6frg6so-1227109697194?nk=939e3fb0f742607b1f6cfcd70c87a498', 0, 'Canada joins Australia in restricting visas amid Ebola scare', 'society', 0, '2014-11-01 14:47:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(544, 1, 'http://news.nationalpost.com/2014/11/01/bangladesh-suffers-nationwide-blackout-after-line-transferring-power-from-india-fails/', 0, 'Bangladesh suffers nationwide blackout after line transferring power from India fails', 'worldnhistory', 0, '2014-11-01 14:47:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(545, 1, 'http://www.theguardian.com/media/2014/nov/03/murdered-journalists-90-of-killers-get-away-with-it-but-who-are-the-victims', 0, 'Murdered journalists: 90% of killers get away with it but who are the victims?', 'worldnhistory', 0, '2014-11-04 07:36:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(546, 1, 'http://www.thestar.com/news/crime/2014/11/04/lawyer_missing_along_with_35_million_in_clients_money.html', 0, 'Lawyer missing along with $3.5 million in clients\' money', 'society', 0, '2014-11-05 09:45:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(547, 1, 'http://www.ehow.com/how_4722291_stop-being-nice.html', 0, 'How to Stop Being Too Nice', 'society', 0, '2014-11-08 15:43:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(548, 1, 'https://uk.answers.yahoo.com/question/index?qid=20080517151222AAvoP6P', 0, 'I am in a wheelchair & i don\'t want to go out no more, why do people laugh at people less fortunate than them?', 'society', 19, '2014-11-10 09:44:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(549, 1, 'http://www.bbc.com/news/health-29442642', 0, 'Aids: Origin of pandemic \'was 1920s Kinshasa\'', 'scintech', 20, '2014-11-10 09:44:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(550, 1, 'http://www.buzzfeed.com/johanabhuiyan/uber-nyc-general-manger-faced-disciplinary-actions-for-priva?utm_term=4ldqpia', 0, 'Uber NYC General Manager Faced â€œDisciplinary Actionsâ€ For Privacy Violations', 'society', 0, '2014-11-30 05:06:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(551, 1, 'http://www.theprovince.com/news/those+moments+that+live+science+researchers+have+found/10658583/story.html', 0, 'Scientists Accidentally Discover How To Turn Off Skin Aging Gene', 'scintech', 0, '2014-12-17 08:07:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(552, 1, 'http://news.ubc.ca/2014/12/16/ubc-scientist-finds-genetic-wrinkle-to-block-sun-induced-skin-aging/', 0, 'UBC scientist finds genetic wrinkle to block sun-induced skin aging', 'scintech', 0, '2014-12-17 08:36:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(553, 1, 'http://news.sciencemag.org/social-sciences/2014/12/want-influence-world-map-reveals-best-languages-speak', 0, 'Best Languages To Speak In Order To Influence The World', 'society', 0, '2014-12-17 08:39:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(554, 1, 'http://www.bloomberg.com/news/2014-12-24/spy-agency-to-release-reports-documenting-surveillance-errors.html', 0, 'U.S. Spy Agency Reports Improper Surveillance of Americans', 'society', 0, '2014-12-25 22:36:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(555, 1, 'http://qz.com/317309/how-some-of-americas-most-gifted-kids-wind-up-in-prison/', 0, 'How some of Americaâ€™s most gifted kids wind up in prison', 'society', 0, '2014-12-25 22:36:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(556, 1, 'http://www.nytimes.com/2015/01/04/us/fbi-employees-with-ties-abroad-see-security-bias.html?_r=0', 0, 'F.B.I. Employees With Ties Abroad See Security Bias', 'society', 0, '2015-01-04 12:28:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(557, 1, 'http://www.theglobeandmail.com/life/health-and-fitness/health/media-can-help-slow-spread-of-disease-study-finds/article22514328/', 0, 'Media Can Help Slow The Spread Of Disease', 'scintech', 0, '2015-01-19 08:09:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(558, 1, 'http://www.nzherald.co.nz/business/news/article.cfm?c_id=3&objectid=11388583', 0, '1% Holds Half The World\'s Wealth', 'society', 0, '2015-01-19 08:10:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(559, 1, 'http://lifehacker.com/what-i-wish-i-knew-when-i-started-my-career-as-a-softwa-1681002791', 0, 'What I Wish I Knew When I Started My Career As A Software Engineer', 'society', 0, '2015-01-26 03:08:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(560, 1, 'http://newszoom.com/index.php/10-ideas-for-a-first-date/', 0, '10 Ideas For A First Date', 'society', 0, '2015-01-26 04:02:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(561, 1, 'http://gizmodo.com/the-army-just-open-sourced-its-security-software-1683023527', 0, 'The Army Just Open Sourced Its Security Software', 'scintech', 0, '2015-02-02 11:32:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(562, 1, 'http://www.iflscience.com/health-and-medicine/cheap-smartphone-dongle-diagnoses-hiv-and-syphilis-15-minutes', 0, 'Cheap Smartphone Dongle Diagnoses HIV And Syphilis In 15 Minutes', 'scintech', 0, '2015-02-09 03:38:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(563, 1, 'http://www.telegraph.co.uk/finance/jobs/9070027/Recruiters-have-racial-bias-claims-report.html', 0, 'Recruiters \'have racial bias\', claims report', 'society', 0, '2015-02-09 11:30:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(564, 1, 'http://changefromwithin.org/2012/06/06/are-white-students-being-disadvantaged-by-affirmative-action/', 0, 'Are White Students Being Disadvantaged by Affirmative Action?', 'society', 0, '2015-02-09 11:33:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(565, 1, 'http://www.dmiblog.com/archives/2007/09/white_convicts_as_likely_to_be.html', 0, 'White Convicts As Likely to Be Hired As Blacks Without Criminal Records', 'society', 0, '2015-02-09 11:35:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(566, 1, 'http://www.washingtonpost.com/blogs/wonkblog/wp/2015/02/10/your-lifetime-earnings-are-probably-determined-in-your-twenties/', 0, 'Your lifetime earnings are probably determined in your 20s', 'society', 0, '2015-02-11 12:25:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(567, 1, 'http://www.bettermicrowave.com/', 0, 'A Better Design For A Microwave', 'scintech', 0, '2015-02-12 12:09:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(568, 1, 'http://thestack.com/russia-ban-tor-vpn-roskomnadzor-110215', 0, 'Russia readying for attempt to ban Tor, VPNs and other anonymising tools', 'worldnhistory', 0, '2015-02-12 12:13:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(569, 1, 'http://advancedphptutorial.blogspot.in/2015/02/drag-and-drop-newsletter-builder-using.html', 0, 'Drag & Drop Newsbuilder Using PHP', 'scintech', 0, '2015-02-12 12:30:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(570, 1, 'http://abcnews.go.com/International/wireStory/officials-inmates-suicide-failed-breakout-taiwan-28908679', 0, 'Taiwan: Inmates Commit Suicide After Failed Prison Breakout', 'society', 0, '2015-02-12 12:35:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(571, 1, 'http://www.cracked.com/blog/4-common-morals-designed-to-keep-you-poor/', 0, '4 Common Morals Designed to Keep You Poor', 'society', 0, '2015-02-13 12:41:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(572, 1, 'http://www.bostonglobe.com/news/world/2014/11/14/isis-leader-says-group-will-mint-its-own-coins/kaOYWSlRA58MthSC1osA7M/story.html', 0, 'ISIS leader says group will mint its own coins', 'worldnhistory', 21, '2015-02-15 04:07:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(573, 1, 'http://www.bloomberg.com/graphics/2015-dark-science-of-interrogation/?hootPostID=a8431611f0f6b91cdbd603f49f2bf585', 0, 'THE DARK SCIENCE OF INTERROGATION', 'society', 0, '2015-02-15 04:07:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(574, 1, 'http://thoughtcatalog.com/anne-gus/2014/03/sorry-dudes-heres-5-reasons-that-girl-you-like-doesnt-want-anything-to-do-with-you/', 0, 'Sorry Dudes: Hereâ€™s 5 Reasons That Girl You Like Doesnâ€™t Want Anything To Do With You', 'sexndating', 0, '2015-02-15 15:28:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(575, 1, 'http://www.theguardian.com/science/2015/feb/15/18th-century-doctors-cut-up-bodies-teach-dissections-research', 0, '18th century doctors shared bodies to teach dissections, research shows', 'worldnhistory', 0, '2015-02-15 20:20:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(576, 1, 'http://www.nytimes.com/2015/02/15/world/bank-hackers-steal-millions-via-malware.html', 0, 'Bank Hackers Steal Millions Via Malware', 'scintech', 0, '2015-02-15 20:22:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(577, 1, 'http://www.reuters.com/article/2015/02/15/us-mideast-crisis-libya-egypt-idUSKBN0LJ10D20150215', 0, 'Islamic State releases video purporting to show beheading of 21 Egyptians in Libya', 'worldnhistory', 0, '2015-02-15 20:22:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(578, 1, 'http://science.slashdot.org/story/15/02/15/1739223/researcher-developing-tattoo-removal-cream', 0, 'Researcher Developing Tattoo Removal Cream', 'scintech', 0, '2015-02-15 20:23:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(579, 1, 'http://www.imcreator.com/blog/9-great-sites-get-web-design-jobs/', 0, '9 GREAT SITES TO GET WEB DESIGN JOBS', 'scintech', 0, '2015-02-15 20:26:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(580, 1, 'http://www.theguardian.com/society/2015/feb/15/students-smart-drugs-higher-grades-adderall-modafinil?CMP=fb_gu', 0, 'Students used to take drugs to get high. Now they take them to get higher grades', 'society', 0, '2015-02-16 02:46:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(581, 1, 'http://fusion.net/story/48952/americas-record-high-grad-rate-isnt-so-impressive/', 0, 'Americaâ€™s record-high grad rate isnâ€™t so impressive', 'society', 0, '2015-02-16 04:05:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(582, 1, 'http://www.engadget.com/2015/02/20/jerry-lawson-game-pioneer/', 0, 'Jerry Lawson, a self-taught engineer, gave us video game cartridges', 'scintech', 0, '2015-02-22 03:40:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(583, 1, 'http://www.theatlantic.com/business/archive/2015/02/white-privilege-quantified/386102/', 0, 'White Privilege Quantified', 'general', 0, '2015-02-26 18:53:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(584, 1, 'http://www.bloomberg.com/politics/articles/2015-02-26/the-return-of-the-death-of-obamacare-i6m1baro', 0, 'Is Washington Ready for the Death of Obamacare?', 'worldnhistory', 0, '2015-02-26 19:28:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(585, 1, 'http://qz.com/351281/chinas-great-firewall-is-demolishing-foreign-websites-and-nobody-knows-why/', 0, 'Chinaâ€™s Great Firewall is demolishing foreign websitesâ€”and nobody knows why', 'worldnhistory', 0, '2015-03-01 00:27:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(586, 1, 'http://www.theatlantic.com/business/archive/2015/03/how-student-debt-stunts-financial-growth/386300/', 0, 'How Student Debt Stunts Financial Growth', 'society', 0, '2015-03-02 07:01:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(587, 1, 'http://fusion.net/story/58131/i-tried-silicon-valleys-favorite-brain-enhancing-drugs/', 0, 'I tried Silicon Valleyâ€™s favorite â€˜brain-enhancingâ€™ drugs', 'body', 0, '2015-03-05 06:46:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(588, 1, 'http://bigstory.ap.org/article/a831de73e41c4810a1581a5d89aede71/11-atlanta-educators-convicted-test-cheating-scandal', 0, '11 former Atlanta educators convicted in cheating scandal', 'society', 0, '2015-04-02 07:05:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(589, 1, 'http://www.nytimes.com/2015/04/13/us/politics/hillary-clinton-2016-presidential-campaign.html', 0, 'Hillary Clinton Announces 2016 Presidential Bid', 'worldnhistory', 0, '2015-04-13 02:42:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(590, 1, 'http://www.nytimes.com/2015/04/13/us/politics/hillary-clinton-2016-presidential-campaign.html', 0, 'Hillary Clinton Announces 2016 Presidential Bid', 'worldnhistory', 0, '2015-04-13 02:42:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(591, 1, 'http://www.gizmag.com/go/6571/', 0, 'How is the world\'s wealth distributed?', 'general', 0, '2015-05-30 09:10:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(592, 1, 'https://www.ssa.gov/policy/docs/ssb/v64n4/v64n4p1.html', 0, 'Racial and Ethnic Differences in Wealth and Asset Choices', 'society', 0, '2015-05-30 09:26:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(593, 1, 'http://www.cdc.gov/std/stats12/minorities.htm', 0, 'STDs in Racial and Ethnic Minorities', 'society', 0, '2015-05-30 09:42:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(594, 1, 'http://en.wikipedia.org/wiki/List_of_countries_by_intentional_homicide_rate', 0, 'List of Countries by Intentional Homicide Rates', 'worldnhistory', 0, '2015-05-30 09:55:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(595, 1, 'http://www.motherjones.com/politics/2014/09/college-tuition-increased-1100-percent-since-1978', 0, 'College Has Gotten 12 Times More Expensive in One Generation', 'society', 0, '2015-05-30 13:05:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(596, 1, 'http://www.wired.com/2015/05/helping-poor-pay-broadband-good-us/', 0, 'Why Helping the Poor Pay for Broadband Is Good for Us All', 'society', 0, '2015-06-02 03:27:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(597, 1, 'http://www.dailymail.co.uk/news/article-2723703/The-dawn-new-era-begun-ISIS-supporters-hand-leaflets-Oxford-Street-encouraging-people-newly-proclaimed-Islamic-State.html', 0, 'ISIS supporters hand out leaflets in London\'s Oxford Street', 'society', 0, '2015-06-02 04:58:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(598, 1, 'http://nymag.com/thecut/2015/06/should-we-teach-women-rape-prevention-tactics.html', 0, 'Teaching women methods for preventing rape could substantially reduce their risk of being raped.', 'society', 0, '2015-06-17 10:02:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(599, 1, 'http://io9.com/its-about-to-get-a-lot-harder-to-experiment-on-chimps-1711381991', 0, 'It\'s About To Get A Lot Harder To Experiment On Chimps', 'society', 0, '2015-06-17 10:04:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(600, 1, 'http://www.macleans.ca/education/uniandcollege/women-in-canada-embrace-higher-education-statcan-survey/', 0, 'Young women earn nearly two-thirds of medical degrees', 'society', 0, '2015-06-19 09:49:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(601, 1, 'http://motherboard.vice.com/read/infighting-and-delays-turns-out-baboons-vote-just-like-congress', 0, 'Infighting and Delays: Turns Out Baboons Vote Just Like Congress', 'society', 0, '2015-06-20 09:02:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(602, 1, 'http://money.cnn.com/2015/06/19/pf/medicare-fraud-doctors/index.html?sr=fbmoney0619medicare0430story', 0, 'Doctors and nurses busted for $712 million Medicare fraud', 'society', 0, '2015-06-20 09:49:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(603, 1, 'http://www.nytimes.com/2015/06/29/world/europe/greece-will-shut-banks-in-fallout-from-debt-crisis.html?hp&action=click&pgtype=Homepage&module=first-column-region&region=top-news&WT.nav=top-news&_r=0', 0, 'Greece Will Shut Banks in Fallout From Debt Crisis', 'society', 0, '2015-06-29 11:46:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(604, 1, 'http://www.3ders.org//articles/20150715-3d-bone-printing-project-in-china-to-enter-animal-testing-stage.html', 0, 'China Testing 3D Bone Printing', 'scintech', 0, '2015-07-18 05:41:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(605, 1, 'http://bldgblog.blogspot.ca/2015/08/horse-skull-disco.html', 0, 'Horse Skulls May Have Been Used For Acoustics In Medieval Times', 'worldnhistory', 0, '2015-08-02 15:53:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(606, 1, 'http://www.gizmag.com/non-invasive-spinal-cord-stimulation-restores-movement-paralysis/38719/', 0, 'Non-invasive spinal cord stimulation gets paralyzed legs moving voluntarily again', 'body', 0, '2015-08-03 03:47:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(607, 1, 'http://arstechnica.com/science/2015/08/your-inherited-genes-control-your-iq-and-may-affect-how-well-you-do-at-exams-too/', 0, 'Your inherited genes control your IQ and may affect how well you do at exams', 'society', 0, '2015-08-03 14:42:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(608, 1, 'https://ca.news.yahoo.com/flipped-classroom-sees-kids-homework-school-watching-online-160012159.html', 0, '\'Flipped\' classroom sees kids do homework at school after watching online videos', 'worldnhistory', 0, '2015-08-18 11:49:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(609, 1, 'http://www.huffingtonpost.com/entry/ben-carson-abortion_55cdf1afe4b07addcb42a449?utm_hp_ref=politics&ir=Politics&section=politics&kvcommref=mostpopular&ref=yfp', 0, 'Ben Carson Says Abortions Are Main Cause Of Death For Black People', 'society', 0, '2015-08-18 11:53:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(610, 1, 'https://www.linkedin.com/pulse/retraining-your-experiences-how-defeat-negative-chopra-md-official-?trk=hp-feed-article-title-hpm', 0, 'Retraining Your Experiences: How to Defeat Negative Biases', 'general', 0, '2015-08-30 02:24:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(611, 1, 'http://www.bbc.com/news/health-32233570', 0, 'Plucking hairs can make more grow', 'body', 0, '2015-08-30 19:35:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(612, 1, 'http://qz.com/492198/murder-rates-are-rising-across-america-but-nobody-knows-why/', 0, 'Murder rates are rising across Americaâ€”but nobody knows why', 'society', 0, '2015-09-02 10:43:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(613, 1, 'http://nymag.com/thecut/2015/09/gender-ratios-and-the-math-of-romance.html', 0, 'Gender Ratios and the Math of Romance', 'society', 0, '2015-09-05 03:36:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(614, 1, 'https://www.cambodiadaily.com/archives/former-manager-admits-stealing-2-3m-from-canadia-bank-44689/', 0, 'Former Manager Admits Stealing $2.3M From Canadia Bank', 'society', 0, '2015-09-07 00:49:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(615, 1, 'http://www.bbc.com/future/story/20150906-the-best-and-worst-ways-to-spot-a-liar', 0, 'How to Spot a Liar', 'body', 0, '2015-09-08 04:09:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(616, 1, 'https://youtu.be/DljWyRQFrNc', 0, 'How to make rope from grass', 'worldnhistory', 0, '2015-09-08 04:41:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(617, 1, 'http://www.slate.com/articles/business/moneybox/2015/09/harvard_yale_stanford_endowments_is_it_time_to_tax_them.html', 0, 'Is It Time to Tax Harvardâ€™s Endowment?', 'society', 0, '2015-09-09 01:47:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(618, 1, 'http://www.nytimes.com/2015/09/13/magazine/is-college-tuition-too-high.html?_r=0', 0, 'Is College Tuition Really Too High?', 'society', 0, '2015-09-09 01:48:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(619, 1, 'https://ca.news.yahoo.com/scroungers-pretend-ali-g-mess-123939258.html', 0, 'Benefit \'Scroungers\' Are Messing Up Job Interviews On Purpose So They Can Continue Claiming', 'society', 0, '2015-09-16 09:16:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(620, 1, 'http://www.investopedia.com/articles/investing/040515/what-education-do-you-need-become-billionaire.asp', 0, 'What Education Do You Need To Become A Billionaire?', 'society', 0, '2015-09-16 11:34:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(621, 1, 'http://www.americanthinker.com/blog/2015/08/trumping_the_donald_on_affirmative_action_.html', 0, 'Trumping The Donald on Affirmative Action', 'society', 0, '2015-09-19 15:44:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(622, 1, 'http://www.cbc.ca/toronto/features/crimemap/', 0, 'Toronto Crime Map', 'society', 0, '2015-09-20 09:30:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(623, 1, 'http://www.statista.com/statistics/300528/us-millionaires-race-ethnicity/', 0, 'Distribution of U.S. millionaires by race/ethnicity, as of 2013', 'society', 0, '2015-09-20 10:09:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(624, 1, 'http://www.statista.com/statistics/204100/distribution-of-global-wealth-top-1-percent-by-country/', 0, 'Members of the global top 1 percent of ultra high net worth individuals in 2014, by country (in 1,000)', 'worldnhistory', 0, '2015-09-20 10:09:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(625, 1, 'http://www.statista.com/chart/3624/the-countries-with-the-most-students-studying-abroad/', 0, 'The Countries With The Most Students Studying Abroad', 'worldnhistory', 0, '2015-09-20 10:11:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(626, 1, 'http://www.statista.com/chart/3588/the-wealthiest-universities-in-the-united-states/', 0, 'The Wealthiest Private Universities In The United States', 'society', 0, '2015-09-20 10:13:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(627, 1, 'http://www.statista.com/chart/3686/wealthy-and-educated-americans-drink-the-most/', 0, 'Wealthy And Educated Americans Drink The Most', 'society', 0, '2015-09-20 10:14:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(628, 1, 'http://www.statista.com/chart/3559/the-countries-with-the-most-engineering-graduates/', 0, 'The Countries With The Most Engineering Graduates', 'worldnhistory', 0, '2015-09-20 10:15:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(629, 1, 'http://edition.cnn.com/2014/12/02/world/asia/myanmar-kachin-heroin-problem/', 0, 'Beyond the sectarian fighting lies Myanmar\'s dark drugs problem', 'worldnhistory', 0, '2015-09-21 04:10:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(630, 1, 'http://www.cbsnews.com/news/krokodil-use-reportedly-spreading-what-makes-dangerous-drug-so-addictive/', 0, 'Krokodil use reportedly spreading', 'society', 0, '2015-09-22 08:05:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(631, 1, 'http://www.theguardian.com/us-news/2015/sep/22/us-republican-candidate-ben-carson-stands-by-anti-muslim-comment', 0, 'US Republican candidate Ben Carson stands by anti-Muslim comment', 'society', 0, '2015-09-22 09:12:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(632, 1, 'https://www.youtube.com/watch?v=WYeyFI7zUzw', 0, 'Donald Trump on Muslims', 'society', 0, '2015-09-22 11:28:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(633, 1, 'https://www.washingtonpost.com/local/education/survey-more-than-1-in-5-female-undergrads-at-top-schools-suffer-sexual-attacks/2015/09/19/c6c80be2-5e29-11e5-b38e-06883aacba64_story.html?utm_source=nextdraft&utm_medium=email', 0, 'Survey: More than 1 in 5 female undergrads at top schools suffer sexual attacks', 'society', 0, '2015-09-22 11:31:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(634, 1, 'http://www.thedailybeast.com/articles/2015/09/21/crime-is-down-so-why-are-new-yorkers-so-afraid.html', 0, 'Crime Is Downâ€”So Why Are New Yorkers So Afraid?', 'society', 0, '2015-09-22 11:49:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(635, 1, 'http://www.nature.com/news/the-hidden-risks-for-three-person-babies-1.18408', 0, 'The hidden risk for 3 person babies', 'society', 0, '2015-09-23 09:56:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(636, 1, 'http://www.rsc.org/chemistryworld/2014/07/desomorphine-krokodil-podcast', 0, 'Desomorphine', 'society', 0, '2015-09-23 10:21:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(637, 1, 'https://news.vice.com/article/a-yakuza-war-is-brewing-in-japan-and-the-police-are-taking-sides', 0, 'A Yakuza War Is Brewing in Japan â€” And the Police Are Taking Sides', 'society', 0, '2015-09-23 10:23:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(638, 1, 'http://www.thedailybeast.com/articles/2015/09/21/could-mapping-genocide-stop-it-from-happening.html', 0, 'Could Mapping Genocide Stop It From Happening?', 'society', 0, '2015-09-23 10:24:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(639, 1, 'http://www.thedailybeast.com/articles/2015/09/21/could-mapping-genocide-stop-it-from-happening.html', 0, 'Could Mapping Genocide Stop It From Happening?', 'society', 0, '2015-09-23 10:24:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(640, 1, 'http://jobs.aol.com/articles/2015/08/03/personality-type-most-likely-unemployed/', 0, 'Pesonality Type Most Likely To Be Unemployeed', 'society', 0, '2015-09-25 10:11:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(641, 1, 'http://humanresources.about.com/od/badmanagerboss/a/mistakes-managers-make-managing-people.htm', 0, 'Mistakes Managers Make When Managing People', 'society', 0, '2015-09-25 10:11:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(642, 1, 'http://jobs.aol.com/articles/2015/08/26/psychologists-say-something-scary-happens-when-youre-unemployed/', 0, 'Psychologists Say Something Scary Happens When You\'re Unemployed For a While', 'society', 0, '2015-09-25 10:12:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(643, 1, 'http://www.gq.com/story/alps-murder-chevaline', 0, 'How To Get Away With (the Perfect) Murder', 'society', 0, '2015-09-27 07:02:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(644, 1, 'http://news.sciencemag.org/physics/2015/09/light-based-memory-chip-first-permanently-store-data', 0, 'Light Based Memory Enters The Game', 'scintech', 0, '2015-09-27 11:55:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(645, 1, 'http://moviepilot.com/posts/2015/05/05/being-evil-can-be-a-challenge-here-s-how-to-become-a-villain-in-6-easy-steps-2898114?lt_source=external,manual', 0, 'Here\'s How to Become a Villain in 6 Easy Steps', 'society', 0, '2015-09-28 09:35:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(646, 1, 'http://hechingerreport.org/why-do-more-than-half-of-principals-quit-after-five-years/', 0, 'Why do more than half of principals quit after five years?', 'society', 0, '2015-09-28 09:38:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0);
INSERT INTO `articlelinks` (`linkid`, `linktype`, `link`, `imageid`, `title`, `category`, `articleid`, `createdate`, `revisedate`, `voteup`, `votedown`, `voteinternal`, `creatorid`, `numcomments`) VALUES
(647, 1, 'http://www.theglobeandmail.com/news/national/spending-on-doctors-pay-up-6-per-cent-in-2014-report/article26581851/', 0, 'Spending on Canadian doctorsâ€™ pay jumps despite efforts to curb costs', 'society', 0, '2015-09-30 02:34:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(648, 1, 'http://www.cbc.ca/news/business/minimum-wage-rises-in-5-provinces-today-1.3251126', 0, 'Minimum wage rises in 5 provinces today (Canada)', 'society', 0, '2015-10-01 10:58:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(649, 1, 'https://ca.finance.yahoo.com/news/10-things-know-money-30-100022879.html', 0, '10 Things to Know About Money Before Youâ€™re 30', 'society', 0, '2015-10-02 22:56:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(650, 1, 'https://ca.finance.yahoo.com/news/10-things-know-money-30-100022879.html', 0, '10 Things to Know About Money Before Youâ€™re 30', 'society', 0, '2015-10-02 22:56:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(651, 1, 'http://www.thestar.com/news/canada/2015/08/11/relaxed-pot-laws-would-hurt-canadians-health-stephen-harper-says.html', 0, 'Relaxed pot laws would hurt Canadiansâ€™ health, Stephen Harper says', 'society', 0, '2015-10-03 17:53:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(652, 1, 'http://www.theguardian.com/world/2015/may/06/murder-map-latin-america-leads-world-key-cities-buck-deadly-trend', 0, 'Latin America leads world on murder map, but key cities buck deadly trend', 'society', 0, '2015-10-04 14:42:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(653, 1, 'http://www.mensfitness.com/nutrition/supplements/miracle-weight-loss-pill-irisin-allows-for-easy-workouts', 0, 'Miracle Weight Loss Pill Irisin', 'body', 0, '2015-10-04 23:52:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(654, 1, 'http://www.elephantjournal.com/2013/10/10-ways-to-handle-douchebags-who-ruin-your-life-because-they-want-to-be-happy-at-the-expense-of-others/', 0, '10 Ways to Handle Douchebags who Ruin your Life because they Want to be Happy at the Expense of Others.', 'society', 0, '2015-10-06 02:59:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(655, 1, 'http://www.sciencealert.com/a-canadian-start-up-is-removing-co2-from-the-air-and-turning-it-into-pellets', 0, 'A Canadian start-up is removing CO2 from the air and turning it into pellets', 'scintech', 0, '2015-10-12 12:27:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(656, 1, 'http://www.sciencealert.com/a-canadian-start-up-is-removing-co2-from-the-air-and-turning-it-into-pellets', 0, 'A Canadian start-up is removing CO2 from the air and turning it into pellets', 'scintech', 0, '2015-10-12 12:27:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(657, 1, 'http://www.irishtimes.com/news/social-affairs/black-africans-face-most-racist-abuse-in-ireland-says-report-1.2146079', 0, '\'Black Africans\' face most racist abuse in Ireland, says report', 'worldnhistory', 0, '2015-10-16 08:12:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(658, 1, 'http://www.peruthisweek.com/news-peruvian-congress-voted-down-gay-rights-law-100310', 0, 'Peruvian Congress voted down gay rights law', 'worldnhistory', 0, '2015-10-16 21:48:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(659, 1, 'http://www.theatlantic.com/health/archive/2015/10/how-antibiotic-resistance-could-make-common-surgeries-more-dangerous/410782/', 0, 'How Antibiotic Resistance Could Make Common Surgeries More Dangerous', 'scintech', 0, '2015-10-18 02:47:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(660, 1, 'https://medium.com/story-tellers/when-the-water-ran-cold-f10a8715f5f3', 0, 'How Growing Old Feels Like', 'body', 0, '2015-10-18 12:00:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(661, 1, 'http://globalnews.ca/news/399273/hallucinogenic-salvia-remains-in-legal-limbo-2/', 0, 'Hallucinogenic salvia remains in legal limbo', 'society', 0, '2015-10-19 05:12:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(662, 1, 'http://www.thedailybeast.com/articles/2015/10/18/this-is-your-brain-on-love.html?via=newsletter&source=DDMorning', 0, 'This is your Brain on Love', 'sexndating', 0, '2015-10-20 12:11:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(663, 1, 'http://www.bloomberg.com/news/articles/2015-10-20/the-real-cost-of-an-mba-is-different-for-men-and-women', 0, 'The Real Payoff From an MBA Is Different for Men and Women', 'society', 0, '2015-10-21 04:25:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(664, 1, 'https://therealrahel.wordpress.com/tag/fighting-racism-through-humor/', 0, 'Spreading awareness about racism and stereotyping through humor', 'society', 0, '2015-10-23 11:29:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(665, 1, 'http://www.telegraph.co.uk/news/health/news/5090078/Salvia-more-powerful-than-LSD-and-legal.html', 0, 'Salvia: more powerful than LSD, and legal', 'society', 0, '2015-10-24 05:01:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(666, 1, 'http://www.nature.com/news/dead-star-spotted-eating-planetary-leftovers-1.18593', 0, 'Dead star spotted eating planetary leftovers', 'scintech', 0, '2015-10-24 05:05:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(667, 1, 'https://www.youtube.com/watch?v=NEM0WyFyuqE', 0, 'Sensations the opposite sex will never experience', 'body', 0, '2015-10-24 15:04:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(668, 1, 'http://blogs.reuters.com/great-debate/2015/06/18/a-child-born-today-may-live-to-see-humanitys-end-unless/', 0, 'A child born today may live to see humanityâ€™s end, unlessâ€¦', 'scintech', 0, '2015-10-24 18:48:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(669, 1, 'http://www.bloombergview.com/articles/2013-06-25/paula-deen-s-racist-wedding-fantasy-was-once-reality', 0, 'Paula Deenâ€™s Racist Wedding Fantasy Was Once Reality', 'society', 0, '2015-10-24 21:36:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(670, 1, 'http://www.independent.co.uk/news/world/europe/portugal-decriminalised-drugs-14-years-ago-and-now-hardly-anyone-dies-from-overdosing-10301780.html', 0, 'Portugal & Drug Decriminalization', 'society', 0, '2015-10-25 03:10:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(671, 1, 'http://www.npr.org/sections/health-shots/2015/10/25/451169292/could-depression-be-caused-by-an-infection?utm_medium=RSS&utm_campaign=science', 0, 'Could Depression Be Caused By An Infection', 'body', 0, '2015-10-25 15:59:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(672, 1, 'https://www.youtube.com/watch?v=5z1K4wMBhZ4', 0, 'Kava - Drink of the Gods', 'worldnhistory', 0, '2015-10-25 16:52:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(673, 1, 'http://time.com/4086607/jimmy-morales-guatemala-president/', 0, 'Comedian Jimmy Morales Wins Guatemalan Presidential Election by Landslide', 'society', 0, '2015-10-26 04:56:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(674, 1, 'http://www.thedailybeast.com/articles/2015/10/25/japan-s-yakuza-cancels-halloween.html?via=newsletter&source=DDMorning', 0, 'Japanâ€™s Yakuza Cancels Halloween', 'worldnhistory', 0, '2015-10-26 05:40:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(675, 1, 'https://ca.style.yahoo.com/post/131758582395/is-this-japanese-makeup-ad-a-comment-on-gender', 0, 'Is this Japanese makeup ad a comment on gender fluidity?', 'worldnhistory', 0, '2015-10-27 05:39:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(676, 1, 'http://www.bloomberg.com/news/articles/2015-10-25/health-medication-errors-happen-in-half-of-all-surgeries', 0, 'Hospitals Mess Up Medications in Surgeryâ€”a Lot', 'society', 0, '2015-10-27 11:36:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(677, 1, 'http://www.inc.com/ilan-mochari/how-nasty-infection-inspired-this-doctor-rating-startup.html', 0, 'How a Botched Surgery Led This Founder to Create a Doctor Rating System', 'society', 0, '2015-10-29 06:42:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(678, 1, 'http://www.theestablishment.co/2015/10/30/online-dating-racism-matchmaking/', 0, 'Yes, Your Dating Preferences Are Probably Racist', 'sexndating', 0, '2015-10-31 02:48:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(679, 1, 'http://www.atlasobscura.com/articles/the-ancient-greeks-sacrificed-ugly-people', 0, 'THE ANCIENT GREEKS SACRIFICED UGLY PEOPLE', 'worldnhistory', 0, '2015-10-31 02:55:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(680, 1, 'https://ca.celebrity.yahoo.com/post/132212834598/roman-polanski-wont-be-extradited-to-us-polish', 0, 'Roman Polanski Wonâ€™t Be Extradited to U.S., Polish Court Rules', 'worldnhistory', 0, '2015-10-31 03:57:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(681, 1, 'https://ca.news.yahoo.com/muslim-montrealer-says-she-told-195609360.html', 0, 'Muslim Montrealer says she was told by Costco employee, \'Go back to your country\'', 'society', 0, '2015-10-31 03:58:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(682, 1, 'http://www.buzzfeed.com/jinamoore/when-youre-a-refugee-and-your-husband-beats-you-youre-basica#.frGvE5ZaE', 0, 'When Youâ€™re a Refugee and Your Husband Beats You, Youâ€™re Basically On Your Own', 'society', 0, '2015-10-31 13:08:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(683, 1, 'http://graphics.wsj.com/ally-settlement-race-calculator/', 0, 'How the Government Predicts Race and Ethnicity', 'scintech', 0, '2015-10-31 13:09:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(684, 1, 'http://www.hopesandfears.com/hopes/now/question/216757-why-are-most-fda-food-recalls-voluntary', 0, 'Why are most hazardous food recalls voluntary?', 'society', 0, '2015-10-31 13:10:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(685, 1, 'http://www.pewresearch.org/fact-tank/2014/12/12/racial-wealth-gaps-great-recession/', 0, 'Wealth inequality has widened along racial, ethnic lines since end of Great Recession', 'society', 0, '2015-10-31 14:28:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(686, 1, 'http://www.forbes.com/sites/laurashin/2015/03/26/the-racial-wealth-gap-why-a-typical-white-household-has-16-times-the-wealth-of-a-black-one/', 0, 'The Racial Wealth Gap: Why A Typical White Household Has 16 Times The Wealth Of A Black One', 'society', 0, '2015-10-31 14:28:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(687, 1, 'http://inequality.org/racial-inequality/', 0, 'Racial Gaps in Income and Wealth, 1989-2013', 'society', 0, '2015-10-31 14:30:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(688, 1, 'https://en.wikipedia.org/wiki/Covert_racism', 0, 'Covert Racism', 'society', 0, '2015-10-31 14:54:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(689, 1, 'http://www.nytimes.com/2015/11/01/magazine/bread-is-broken.html?utm_source=nextdraft&utm_medium=email&_r=0', 0, 'Bread Is Broken', 'scintech', 0, '2015-10-31 16:07:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(690, 1, 'http://nautil.us/blog/the-word-million-didnt-exist-until-we-needed-it', 0, 'The Word â€œMillionâ€ Didnâ€™t Exist Until We Needed It', 'worldnhistory', 0, '2015-10-31 16:07:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(691, 1, 'https://ca.news.yahoo.com/anonymous-plans-unhood-1-000-025419413.html', 0, 'Anonymous plans to \'unhood\' 1,000 Ku Klux Klan members online', 'society', 0, '2015-11-01 03:45:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 1),
(692, 1, 'http://www.dailymail.co.uk/news/article-1230294/The-true-story-The-Great-Escape-revealed-airmans-World-War-II-diary.html', 0, 'The true story behind The Great Escape revealed in an airman\'s World War II diary', 'society', 0, '2015-11-01 15:12:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(693, 1, 'http://lifehacker.com/how-much-it-actually-costs-to-be-in-a-long-distance-rel-1740081945?utm_campaign=socialflow_lifehacker_twitter&utm_source=lifehacker_twitter&utm_medium=socialflow', 0, 'How Much It Actually Costs to Be in a Long Distance Relationship', 'sexndating', 0, '2015-11-05 11:10:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(694, 1, 'http://www.cbc.ca/news/canada/edmonton/u-of-a-study-finds-risk-of-head-injuries-higher-for-boxers-1.3306615', 0, 'U of A study finds risk of head injuries higher for boxers', 'body', 0, '2015-11-06 11:06:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(695, 1, 'https://youtu.be/SUnobHHAKxo', 0, 'The KKK vs. the Crips vs. Memphis City Council', 'society', 0, '2015-11-07 01:38:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(696, 1, 'https://ca.style.yahoo.com/post/132749850095/religious-kids-arent-as-good-at-sharing-study', 0, 'Religious Kids Arenâ€™t as Good at Sharing, Study Finds', 'society', 0, '2015-11-08 00:27:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(697, 1, 'http://www.theguardian.com/theguardian/2005/sep/23/features2.g2', 0, 'Why I hate cocaine', 'general', 0, '2015-11-08 01:46:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(698, 1, 'https://ca.finance.yahoo.com/news/why-layoffs-hurt-both-companies-201400143.html', 0, 'Why layoffs hurt both companies and employees', 'society', 0, '2015-11-08 13:01:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(699, 1, 'http://www.cbc.ca/news/canada/manitoba/whooping-cough-outbreak-in-manitoba-blamed-on-parents-not-immunizing-1.3307714', 0, 'Whooping cough outbreak in Manitoba blamed on parents not immunizing', 'society', 0, '2015-11-08 15:22:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(700, 1, 'http://humanorigins.si.edu/human-characteristics', 0, 'Human Characteristics: What Does it Mean to be Human', 'body', 0, '2015-11-08 15:29:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(701, 1, 'https://ca.news.yahoo.com/this-is-why-most-people-are-right-handed-153016302.html', 0, 'This Is Why Most People Are Right-Handed', 'worldnhistory', 0, '2015-11-09 01:35:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(702, 1, 'http://www.reuters.com/article/2015/11/09/us-virginia-sexcrimes-idUSKCN0SY2CV20151109#qg7GDfQF6RI3KWFM.97', 0, 'Virginia fraternity sues Rolling Stone over rape story', 'society', 0, '2015-11-10 03:28:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(703, 1, 'http://www.newyorker.com/news/news-desk/race-and-the-free-speech-diversion', 0, 'Race and the Free-Speech Diversion', 'society', 0, '2015-11-11 18:13:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(704, 1, 'http://canadajournal.net/health/canadian-doctors-breach-the-blood-brain-barrier-37736-2015/', 0, 'Canadian Doctors Breach the Blood-Brain Barrier', 'scintech', 0, '2015-11-11 22:34:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(705, 1, 'http://www.hopesandfears.com/hopes/now/question/216821-divorce-bad', 0, 'Is divorce really that bad?', 'sexndating', 0, '2015-11-13 06:55:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(706, 1, 'https://aeon.co/essays/can-parents-be-trusted-with-gene-editing-technology', 0, 'Can parents be trusted with gene editing?', 'scintech', 0, '2015-11-13 06:56:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(707, 1, 'http://www.thestar.com/news/insight/2015/11/13/two-identical-twins-one-was-raised-jewish-the-other-became-a-nazi.html', 0, 'Two identical twins. One was raised Jewish, the other became a Nazi', 'worldnhistory', 0, '2015-11-14 13:34:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(708, 1, 'http://www.statnews.com/2015/11/13/medical-experiments-horrible-unethical-also-useful/', 0, 'These medical experiments were horrible, unethical â€” and useful', 'scintech', 0, '2015-11-15 14:20:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(709, 1, 'http://www.bbc.com/news/magazine-32529679', 0, 'The rape of Berlin', 'worldnhistory', 0, '2015-11-16 11:15:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(710, 1, 'http://thehappysensitive.com/how-to-stop-being-empathic-and-become-a-complete-narcissist-a-k-a-arsecissist/', 0, 'How to Stop Being Empathic and Become a Complete Narcissist (a.k.a. Arsecissist)', 'society', 0, '2015-11-21 14:43:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(711, 1, 'http://www.hopesandfears.com/hopes/now/question/216881-why-do-people-want-to-be-good', 0, 'Why do people want to be good?', 'society', 0, '2015-11-23 23:17:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(712, 1, 'http://www.theatlantic.com/international/archive/2015/11/how-is-isis-still-making-money/416745/', 0, 'How Is ISIS Still Making Money?', 'worldnhistory', 0, '2015-11-23 23:18:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(713, 1, 'http://www.vancouversun.com/opinion/columnists/barbara+yaffe+time+government+intervention+real/11541248/story.html', 0, 'Time for government intervention in real estate market', 'society', 0, '2015-11-25 05:28:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(714, 1, 'https://www.washingtonpost.com/news/speaking-of-science/wp/2015/11/24/apparently-earth-is-sprouting-dark-matter-hairs/', 0, 'Earth is sprouting dark matter â€˜hairsâ€™', 'scintech', 0, '2015-11-25 05:29:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(715, 1, 'https://medium.com/backchannel/arresting-crime-before-it-happens-6cc8ad24d0e3#.nt6ftha7v', 0, 'Arresting Crime Before It Happens', 'society', 0, '2015-11-28 22:16:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(716, 1, 'http://phys.org/news/2015-11-phase-carbon-diamond-room-temperature.html', 0, 'Researchers find new phase of carbon, make diamond at room temperature', 'scintech', 0, '2015-12-01 22:38:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(717, 1, 'http://digg.com/2015/condom-hiv-fighting', 0, 'A Condom That Fights HIV', 'scintech', 0, '2015-12-01 22:38:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(718, 1, 'http://www.nytimes.com/2015/12/06/magazine/the-last-dalai-lama.html?_r=0', 0, 'The Last Dalai Lama?', 'worldnhistory', 0, '2015-12-01 22:39:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(719, 1, 'https://www.linkedin.com/pulse/big-idea-2016-lets-find-better-way-elect-our-t-boone-pickens?trk=hp-feed-article-title-hpm', 0, 'Letâ€™s Find a Better Way to Elect Our President', 'society', 0, '2015-12-19 03:47:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(720, 1, 'https://www.washingtonpost.com/world/national-security/president-obama-commutes-sentences-of-about-100-drug-offenders/2015/12/18/9b62c91c-a5a3-11e5-9c4e-be37f66848bb_story.html', 0, 'President Obama commutes sentences of 95 federal drug offenders', 'worldnhistory', 0, '2015-12-19 04:23:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(721, 1, 'http://www.buzzfeed.com/mbvd/life-on-mars?bftwnews&utm_term=.uqZp5Zwd4j#.vp4WvGpAVm', 0, 'Six Strangers Are Living In A Dome To Prepare For Life On Mars', 'worldnhistory', 0, '2015-12-19 04:31:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(722, 1, 'http://www.investopedia.com/articles/forex/031714/how-forex-fix-may-be-rigged.asp', 0, 'How The Forex Market May Be Fixed', 'worldnhistory', 0, '2015-12-26 02:15:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(723, 1, 'http://www.bbc.com/news/business-32817114', 0, 'Big Banks Plead Guilty To Fixing Currency Market', 'society', 0, '2015-12-26 03:30:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(724, 1, 'http://www.independenttraveler.com/travel-tips/seasonal-travel/7-places-where-the-dollar-goes-farther', 0, '7 Places Where the Dollar Goes Farther', 'worldnhistory', 0, '2015-12-27 22:27:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(725, 1, 'http://www.forbes.com/2010/10/28/countries-where-dollar-goes-furthest-exchange-rates-personal-finance-cheap-travel_slide.html', 0, 'Eight Countries Where The Dollar Goes Furthest', 'worldnhistory', 0, '2015-12-27 22:31:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(726, 1, 'http://www.bbc.com/future/story/20160103-do-ruthless-people-really-get-ahead', 0, 'Does a dark personality actually help you get to the top of business? The truth is more complex.', 'society', 0, '2016-01-04 06:44:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(727, 1, 'http://www.torontosun.com/2016/01/05/at-least-2250-veterans-are-homeless-according-to-groundbreaking-analysis', 0, 'At least 2,250 veterans are homeless, according to groundbreaking analysis', 'worldnhistory', 0, '2016-01-06 11:35:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(728, 1, 'http://www.torontosun.com/2016/01/05/at-least-2250-veterans-are-homeless-according-to-groundbreaking-analysis', 0, 'At least 2,250 veterans are homeless, according to groundbreaking analysis', 'worldnhistory', 0, '2016-01-06 11:35:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(729, 1, 'http://www.theguardian.com/healthcare-network/views-from-the-nhs-frontline/2016/jan/05/doctor-suicide-hospital-nhs', 0, 'Doctor suicide is the medical professionâ€™s grubby secret ', 'society', 0, '2016-01-07 00:41:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(730, 1, 'http://www.dailymail.co.uk/news/article-3386673/Women-Cologne-lockdown-council-admits-no-longer-safe-wake-African-Arab-mob-s-rapes-declares-upcoming-carnival-no-area-females.html', 0, 'GERMAN AUTHORITIES ACCUSED OF COVERING UP MASS SEXUAL ASSAULT BY HUNDREDS OF MIGRANTS', 'worldnhistory', 0, '2016-01-11 09:19:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(731, 1, 'http://www.ctvnews.ca/canada/burkina-faso-attack-not-first-time-canadians-have-faced-african-al-qaeda-terror-1.2741230', 0, 'Burkina Faso attack not first time Canadians have faced African al Qaeda terror', 'worldnhistory', 0, '2016-01-18 12:56:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(732, 1, 'http://nation.com.pk/business/18-Jan-2016/wealth-of-world-s-richest-1-equal-to-other-99-report', 0, 'Wealth of world\'s richest 1% equal to other 99%: report', 'society', 0, '2016-01-18 12:57:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(733, 1, 'http://ca.reuters.com/article/businessNews/idCAKCN0UV14D', 0, 'Oil slides to lowest since 2003 after Iran sanctions lifted', 'society', 0, '2016-01-18 12:59:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(734, 1, 'http://digg.com/2016/what-is-polonium', 0, 'What Is Polonium?', 'society', 0, '2016-01-24 04:17:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(735, 1, 'http://www.theatlantic.com/science/archive/2016/02/clearing-retired-cells-extends-life/459723/', 0, 'Clearing the Body\'s Retired Cells Slows Aging and Extends Life', 'scintech', 0, '2016-02-05 07:11:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(736, 1, 'http://motherboard.vice.com/read/why-are-stethoscopes-still-a-thing', 0, 'Why Are Stethoscopes Still a Thing?', 'scintech', 0, '2016-02-07 13:39:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(737, 1, 'https://ca.news.yahoo.com/how-a-former-drug-kingpin-1353913695158326.html', 0, 'How a Former Drug Kingpin Transformed His Body and Created a Prison Workout Phenomenon', 'society', 0, '2016-02-08 12:34:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(738, 1, 'http://www.thestar.com/news/gta/2016/02/10/cardiologist-accused-of-over-billing-did-too-many-tests-too-few-exams-expert-testifies.html', 0, 'Cardiologist accused of over-billing did too many tests, too few exams, expert testifies', 'society', 0, '2016-02-11 05:37:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(739, 1, 'https://ca.sports.yahoo.com/news/advises-women-zika-protection-no-travel-advisories-025018753--business.html', 0, 'WHO advises women on Zika protection but no travel advisories', 'worldnhistory', 0, '2016-02-11 05:38:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(740, 1, 'http://priceonomics.com/how-long-do-couples-date-before-getting-engaged/', 0, 'How Long Do Couples Date Before Getting Engaged?', 'sexndating', 0, '2016-02-11 05:39:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(741, 1, 'https://ca.news.yahoo.com/couple-sentenced-today-st-thomas-ont-slaying-woman-090018694.html?nhp=1', 0, 'Couple who raped and killed Sarnia, Ont., teacher says \'sorry\' to her family', 'society', 0, '2016-02-13 07:32:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(742, 1, 'http://www.cbc.ca/news/canada/montreal/lac-simon-shooting-1.3447853', 0, 'Police officer, 2nd man killed in shooting in Lac-Simon, Que.', 'society', 0, '2016-02-15 19:18:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(743, 1, 'http://fox40.com/2016/02/15/1-billion-worth-of-drugs-seized-from-shipment-of-silicon-bra-inserts-in-australia/', 0, '$1 Billion Worth of Drugs Seized From Shipment of Silicone Bra Inserts in Australia', 'worldnhistory', 0, '2016-02-15 19:27:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(744, 1, 'http://www.nature.com/news/brain-doping-may-improve-athletes-performance-1.19534', 0, 'â€˜Brain dopingâ€™ may improve athletesâ€™ performance', 'body', 0, '2016-03-14 12:36:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(745, 1, 'http://www.bloomberg.com/news/articles/2016-03-17/why-minority-applicants-scrape-race-from-their-r-sum-s', 0, 'Why Minority Applicants Scrape Race From Their RÃ©sumÃ©s', 'society', 0, '2016-03-18 22:39:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(746, 1, 'https://www.washingtonpost.com/news/wonk/wp/2016/03/18/how-the-likelihood-of-breaking-up-changes-as-time-goes-by/', 0, 'How the chance of breaking up changes the longer your relationship lasts', 'sexndating', 0, '2016-03-19 11:55:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(747, 1, 'https://www.washingtonpost.com/world/europe/europe-offers-deal-to-turkey-to-take-back-migrants/2016/03/18/809d80ba-ebab-11e5-bc08-3e03a5b41910_story.html', 0, 'E.U. strikes deal to return new migrants to Turkey', 'worldnhistory', 0, '2016-03-19 12:51:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(748, 1, 'http://www.latimes.com/world/mexico-americas/la-fg-obama-cuba-advance-20160318-story.html', 0, 'Obama\'s Cuba visit to augur a \'new beginning\' between nations', 'worldnhistory', 0, '2016-03-19 13:40:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(749, 1, 'http://www.vox.com/2016/3/19/11265464/doctors-misdiagnose-rude-patients', 0, 'Doctors are more likely to misdiagnose patients who are jerks', 'society', 0, '2016-03-20 11:56:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(750, 1, 'http://bostonreview.net/wonders/anne-fausto-sterling-race-medical-school', 0, 'Race in Medical School Curricula', 'society', 0, '2016-03-22 05:11:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(751, 1, 'https://aeon.co/opinions/galileo-s-reputation-is-more-hyperbole-than-truth', 0, 'Galileoâ€™s reputation is more hyperbole than truth', 'worldnhistory', 0, '2016-04-02 14:02:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(752, 1, 'http://learningenglish.voanews.com/content/fidel-castro-rejects-president-obamas-advice-to-leave-the-past-behind/3259814.html', 0, 'Fidel Castro Rejects Obamaâ€™s Advice', 'worldnhistory', 0, '2016-04-02 14:03:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(753, 1, 'http://ordinary-gentlemen.com/2010/05/20/plato-crito-and-should-we-obey-bad-laws/', 0, 'Plato, â€œCritoâ€, and should we obey bad laws?', 'worldnhistory', 0, '2016-04-08 04:37:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(754, 1, 'http://priceonomics.com/online-dating-and-the-death-of-the-mixed/', 0, 'Online Dating and the Death of the \'Mixed-Attractiveness\' Couple', 'society', 0, '2016-04-10 16:12:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(755, 1, 'http://www.buzzfeed.com/alisoncaporimo/blackout-ftw#.py0RdbpBl', 0, '15 Striking Blackout Tattoos That Almost Look Unreal', 'body', 0, '2016-04-10 17:28:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(756, 1, 'http://fusion.net/story/289485/ethel-easter-racist-surgery/', 0, 'A black woman secretly recorded her surgeryâ€”and caught her doctors making racist jokes', 'society', 0, '2016-04-11 11:25:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(757, 1, 'http://www.ocregister.com/articles/tobacco-711873-age-yang.html', 0, 'CSUF expert: Raising the smoking age has benefits', 'society', 0, '2016-04-13 11:16:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(758, 1, 'http://www.wsj.com/articles/peabody-energy-files-for-chapter-11-protection-from-creditors-1460533760', 0, 'Peabody Energy Files For Chapter 11 Bankruptcy Protection', 'worldnhistory', 0, '2016-04-13 11:39:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(759, 1, 'http://www.nomarriage.com/top-ten-reasons-you-shouldnt-get-married/', 0, 'Top Ten Reasons You Shouldnâ€™t Get Married', 'sexndating', 0, '2016-04-18 00:35:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(760, 1, 'http://www.boldsky.com/relationship/love-and-romance/2014/why-you-should-not-have-a-girlfriend-040922.html', 0, 'Why You Should Not Have A Girlfriend: Cons', 'sexndating', 0, '2016-04-18 00:58:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(761, 1, 'https://ca.news.yahoo.com/pot-culture-crash-marijuana-legalization-canada-may-extinguish-191428697.html', 0, 'Pot culture crash? Marijuana legalization in Canada may extinguish drug cachet', 'society', 0, '2016-04-21 23:23:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(762, 1, 'http://www.thestar.com/news/queenspark/2016/04/22/ontarios-top-billing-doctor-charged-ohip-66m-last-year.html', 0, 'Ontarioâ€™s top-billing doctor charged OHIP $6.6M last year', 'society', 0, '2016-04-23 02:53:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(763, 1, 'http://www.wsj.com/articles/tech-shares-fail-to-join-the-party-1461372935', 0, 'Technology sharesâ€‹are struggling to regain favor with investors', 'scintech', 0, '2016-04-23 03:07:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(764, 1, 'http://www.nytimes.com/2016/04/23/world/europe/obama-britain-visit.html?_r=0', 0, 'Obama Warns Britain on Trade if It Leaves European Union', 'worldnhistory', 0, '2016-04-23 03:10:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(765, 1, 'http://www.nytimes.com/2016/04/22/nyregion/new-york-hospital-to-pay-fine-over-unauthorized-filming-of-2-patients.html', 0, 'New York Hospital to Pay $2.2 Million Over Unauthorized Filming of 2 Patients', 'society', 0, '2016-04-23 10:35:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(766, 1, 'http://www.theglobeandmail.com/news/national/more-than-500-ontario-doctors-billed-over-1-million-last-year-hoskins/article29718573/', 0, 'Ontario must clamp down on high-billing doctors, health minister says', 'society', 0, '2016-04-23 11:21:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(767, 1, 'http://www.nytimes.com/2016/04/24/world/asia/bangladesh-professor-killed.html?_r=0', 0, 'Bangladesh Police Suspect Islamist Militants in Professorâ€™s Killing', 'worldnhistory', 0, '2016-04-23 12:01:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(768, 1, 'http://seekingalpha.com/article/3967455-risk-oil-supply-soaring-saudi-arabia-russia-square', 0, 'Risk Of Oil Supply Soaring As Saudi Arabia And Russia Square Off', 'worldnhistory', 0, '2016-04-23 14:49:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(769, 1, 'http://evonomics.com/why-garbage-men-should-earn-more-than-bankers/', 0, 'Why Garbagemen Should Earn More Than Bankers', 'society', 0, '2016-04-23 16:41:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(770, 1, 'https://www.psychologytoday.com/blog/the-urban-scientist/201003/how-spot-friends-enemies-frenemies-and-bullies', 0, 'How to Spot Friends, Enemies, Frenemies and Bullies', 'society', 0, '2016-04-23 17:04:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(771, 1, 'http://www.nugget.ca/2016/04/22/one-doctor-billed-ohip-66-million-the-health-minister-said', 0, 'Health minister calls out medical millionaires club in latest wage war salvo', 'society', 0, '2016-04-23 18:22:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(772, 1, 'http://www.thestar.com/news/canada/2016/04/23/the-criminal-code-is-no-substitute-for-an-ethical-compass-hebert.html', 0, 'The Criminal Code is no substitute for an ethical compass: Hebert', 'society', 0, '2016-04-23 18:23:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(773, 1, 'http://www.investopedia.com/articles/investing/042016/harriet-tubman-replaces-slaveowner-andrew-jackson-20-bill.asp?article=3&utm_campaign=www.investopedia.com&utm_source=forex&utm_term=6568020&utm_medium=email', 0, 'Harriet Tubman Replaces Slave-Owner Andrew Jackson on $20 Bill', 'worldnhistory', 0, '2016-04-23 18:52:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(774, 1, 'http://www.modernreaders.com/days-reality-tv-hospitals-emergency-rooms/44841/ed-jones', 0, 'Feds Fine Hospital for Filming Reality TV Show without Patientsâ€™ Consent', 'society', 0, '2016-04-23 22:42:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(775, 1, 'http://www.dailymail.co.uk/news/article-2984489/The-organ-snatchers-Boy-12-smuggled-UK-gang-sell-body-parts-black-market.html', 0, 'Boy of 12 smuggled into UK... for gang to sell his body parts on black market', 'worldnhistory', 0, '2016-04-24 15:38:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(776, 1, 'http://www.torontosun.com/2016/04/24/organized-crime-may-infiltrate-pot-regime-internal-federal-paper-warns', 0, 'Organized crime \'may infiltrate\' pot regime, internal federal paper warns', 'society', 0, '2016-04-25 02:28:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(777, 1, 'http://www.torontosun.com/2016/04/24/time-for-health-minister-eric-hoskins-to-resign', 0, 'Time for Health Minister Eric Hoskins to resign', 'society', 0, '2016-04-25 02:35:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(778, 1, 'http://losangeles.cbslocal.com/2016/04/24/company-voluntarily-recalls-frozen-vegetables-over-listeria-concerns/', 0, 'Company Voluntarily Recalls Frozen Vegetables Over Listeria Concerns', 'society', 0, '2016-04-25 05:44:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(779, 1, 'https://www.buzzfeed.com/dominicholden/feds-publish-records-on-schools-allowed-to-discriminate-agai?utm_term=.wixvz6MPr#.lhx0w3Mxp', 0, 'Feds Publish Records On Schools Allowed To Discriminate Against LGBT Students', 'society', 0, '2016-05-01 01:27:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(780, 1, 'https://www.youtube.com/watch?v=Tct38KwROdw', 0, 'Giving birth in the USA costs a lot. Hospitals won\'t tell you how much.', 'society', 0, '2016-05-06 10:28:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(781, 1, 'http://www.thedailybeast.com/articles/2016/05/08/the-secret-life-of-sadiq-khan-london-s-first-muslim-mayor.html', 0, 'The Secret Life of Sadiq Khan, Londonâ€™s First Muslim Mayor', 'worldnhistory', 0, '2016-05-08 12:34:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(782, 1, 'http://montreal.ctvnews.ca/body-found-in-plastic-bag-in-st-eustache-1.2895304', 0, 'Body found in plastic bag in St-Eustache, Montreal', 'worldnhistory', 0, '2016-05-10 05:01:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(783, 1, 'http://www.bbc.com/news/world-africa-36296551', 0, 'Nelson Mandela: CIA tip-off led to 1962 Durban arrest', 'worldnhistory', 0, '2016-05-16 11:31:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(784, 1, 'https://youtu.be/ue_KO_Xhi9o', 0, 'The History of Tentacle Porn Animated!', 'worldnhistory', 0, '2016-05-17 10:19:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(785, 1, 'http://www.cnbc.com/2014/03/11/forex-manipulation-how-it-worked.html', 0, 'Forex manipulation: How it worked', 'worldnhistory', 0, '2016-05-18 02:55:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(786, 1, 'https://www.bloomberg.com/view/articles/2014-11-12/banks-manipulated-foreign-exchange-in-ways-you-can-t-teach', 0, 'Banks Manipulated Foreign Exchange in Ways You Can\'t Teach', 'worldnhistory', 0, '2016-05-18 03:00:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(787, 1, 'http://www.investopedia.com/articles/financialcareers/06/mmakertricks.asp', 0, 'How Brokers Can Avoid A Market-Maker\'s Tricks', 'worldnhistory', 0, '2016-05-18 11:38:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(788, 1, 'http://www.popsci.com/what-its-like-to-go-to-mars-and-back', 0, 'WHAT\'S IT LIKE TO GO TO MARS AND BACK?', 'scintech', 0, '2016-05-18 11:43:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(789, 1, 'https://www.washingtonpost.com/news/wonk/wp/2015/05/20/how-cities-are-starting-to-turn-back-decades-of-creeping-urban-blight/', 0, 'How cities are starting to turn back decades of creeping urban blight', 'worldnhistory', 0, '2016-05-19 12:00:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(790, 1, 'https://theseriesphilosopher.wordpress.com/2014/06/13/s03e12-is-honesty-an-impediment-to-career-success/', 0, 'Is honesty an impediment to career success?', 'society', 0, '2016-05-21 17:58:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(791, 1, 'http://www.huffingtonpost.in/amrita-chowdhury-/why-sociopaths-succeed_b_7965882.html', 0, 'Why Sociopaths Succeed', 'society', 0, '2016-05-23 20:49:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(792, 1, 'http://www.cbsnews.com/news/post-traumatic-stress-disorders-effect-on-us-veterans-explored-on-cbs-radio-news/', 0, 'Post-traumatic stress disorder\'s effect on U.S. veterans explored on CBS Radio News', 'society', 0, '2016-05-24 03:31:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(793, 1, 'http://www.rantlifestyle.com/2015/07/05/15-end-of-the-world-predictions-that-ended-up-being-wrong/', 0, '20 End Of The World Predictions That Ended Up Being Wrong', 'worldnhistory', 0, '2016-05-24 03:34:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(794, 1, 'https://features.wearemel.com/what-would-happen-if-we-all-stopped-paying-our-student-loans-be9ff77ef33b#.xz8a9ba9a', 0, 'What Would Happen If We All Stopped Paying Our Student Loans?', 'society', 0, '2016-05-24 03:46:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(795, 1, 'http://www.travelandleisure.com/slideshows/the-worlds-most-dangerous-countries/14', 0, 'The World\'s Most Dangerous Countries', 'worldnhistory', 0, '2016-05-24 04:50:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(796, 1, 'http://www.thesudburystar.com/2016/05/24/casey-anthony-paid-her-lawyer-in-sex-investigator-claims', 0, 'Casey Anthony paid her lawyer in sex, investigator claims', 'society', 0, '2016-05-25 11:55:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(797, 1, 'http://www.theglobeandmail.com/news/politics/harper-will-step-down-as-mp-before-parliaments-fall-session/article30133335/', 0, 'Harper will step down as MP before Parliamentâ€™s fall session', 'worldnhistory', 0, '2016-05-25 11:57:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(798, 1, 'http://www.business-standard.com/article/pti-stories/optics-breakthrough-may-lead-to-better-night-vision-devices-116052500838_1.html', 0, 'Optics breakthrough may lead to better night vision devices', 'scintech', 0, '2016-05-25 12:00:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(799, 1, 'http://www.theglobeandmail.com/opinion/fee-fight-reveals-doctors-sense-of-entitlement/article26669265/', 0, 'Ontario fee fight reveals doctorsâ€™ sense of entitlement', 'society', 0, '2016-06-02 10:07:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(800, 1, 'http://www.forbes.com/sites/theapothecary/2013/05/28/are-u-s-doctors-paid-too-much/#3a85e7813e5c', 0, 'Are U.S. Doctors Paid Too Much?', 'society', 0, '2016-06-02 10:10:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(801, 1, 'http://www.vice.com/read/i-tried-joining-the-french-foreign-legion', 0, 'I Tried Joining the French Foreign Legion', 'worldnhistory', 0, '2016-06-03 01:06:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(802, 1, 'http://www.theguardian.com/commentisfree/2015/dec/22/beauty-pageants-embarrassing-even-if-name-right-winner-miss-universe', 0, 'Beauty pageants are embarrassing â€“ even if you name the right winner', 'society', 0, '2016-06-03 10:56:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(803, 1, 'http://www.ctvnews.ca/world/victims-speak-out-as-malawi-sees-surge-in-attacks-on-albinos-1.2934244', 0, 'Victims speak out as Malawi sees surge in attacks on albinos', 'worldnhistory', 0, '2016-06-07 11:24:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(804, 1, 'https://www.washingtonpost.com/local/education/new-federal-civil-rights-data-show-persistent-racial-gaps-in-discipline-access-to-advanced-coursework/2016/06/06/e95a4386-2bf2-11e6-9b37-42985f6a265c_story.html', 0, 'New federal civil rights data show persistent racial gaps in discipline, access to advanced coursework', 'society', 0, '2016-06-07 11:39:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(805, 1, 'http://www.inquisitr.com/890257/chinks-steaks-opts-for-less-offensive-name-sales-plummet/', 0, 'Chinkâ€™s Steaks Opts For Less Offensive Name, Sales Plummet', 'society', 0, '2016-06-08 23:57:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(806, 1, 'https://www.linkedin.com/pulse/nokia-ceo-ended-his-speech-saying-we-didnt-do-anything-rahul-gupta?trk=hp-feed-article-title-share', 0, 'Nokia CEO ended his speech saying this â€œwe didnâ€™t do anything wrong, but somehow, we lostâ€.', 'society', 0, '2016-06-10 11:15:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(807, 1, 'http://www.vice.com/read/for-context-heres-how-various-societies-punished-rapists', 0, 'A Brief and Depressing History of Rape Laws', 'worldnhistory', 0, '2016-06-11 15:34:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(808, 1, 'http://www.bustle.com/articles/54614-17-gross-things-women-have-to-deal-with-during-our-periods-because-sleep-leakage-is-the', 0, '17 Gross Things Women Have to Deal With During Our Periods, Because Sleep Leakage Is The Least of It', 'body', 0, '2016-06-13 23:42:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(809, 1, 'http://www.americanthinker.com/articles/2016/06/a_physicians_case_for_trump.html', 0, 'A physician\'s case for Trump', 'society', 0, '2016-06-14 11:27:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(810, 1, 'http://wjla.com/news/nation-world/police-respond-to-report-of-barricaded-man-in-n-seattle', 0, 'Police arrest man who allegedly threatened to shoot up Seattle mosque', 'society', 0, '2016-06-15 07:09:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(811, 1, 'http://edition.cnn.com/2016/06/12/us/orlando-nightclub-shooting/', 0, 'Orlando shooting: 49 killed, shooter pledged ISIS allegiance', 'society', 0, '2016-06-15 07:11:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(812, 1, 'http://www.eremedia.com/ere/whats-wrong-with-interviews-the-top-50-most-common-interview-problems/', 0, 'Whatâ€™s Wrong With Interviews? The Top 50 Most Common Interview Problems', 'society', 0, '2016-06-19 10:07:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(813, 1, 'http://www.japantimes.co.jp/news/2016/05/27/national/still-hate-glow-setting-sun-hiroshima-survivors-tales/#.V2nM3PkrLIV', 0, 'The Atomic Bomb - Survivor Tales', 'worldnhistory', 0, '2016-06-21 23:28:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(814, 1, 'https://ca.finance.yahoo.com/blogs/insight/suing-airbnb-over-racial-discrimination-a--complicated-question---human-rights-lawyer-171038732.html', 0, 'Airbnb\'s obligation to prevent discrimination falls into legal grey area', 'society', 0, '2016-06-26 03:14:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(815, 1, 'http://news.bbc.co.uk/2/hi/health/2503603.stm', 0, 'Why we get ill at weekends', 'body', 0, '2016-06-28 00:27:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(816, 1, 'http://healthydebate.ca/2013/03/topic/alcohol-pricing', 0, 'Canadian alcohol pricing research makes waves abroad, not so much at home', 'society', 0, '2016-06-28 01:31:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(817, 1, 'http://www.businessinsider.com/we-can-smell-the-ramped-up-immune-system-of-sick-people-2014-1', 0, 'People Actually Smell Different When They Are Sick', 'body', 0, '2016-06-28 01:38:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(818, 1, 'https://ca.news.yahoo.com/countries-where-marijuana-legal-form-193400717.html', 0, 'Here are the Countries Where Marijuana Is Legal in Some Form', 'worldnhistory', 0, '2016-06-28 03:20:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(819, 1, 'http://www.cbsnews.com/news/mass-casualty-stabbings-nazi-rally-sacramento-california/', 0, '7 stabbed at neo-Nazi event outside Capitol in Sacramento', 'worldnhistory', 0, '2016-06-28 04:04:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(820, 1, 'https://ca.finance.yahoo.com/blogs/insight/on-eve-of-three-amigos-summit-only-one-in-four-125404732.html', 0, 'On eve of Three Amigos summit, only one in four Canadians support NAFTA', 'worldnhistory', 0, '2016-06-28 04:07:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(821, 1, 'https://ca.movies.yahoo.com/18-beloved-celebrities-said-really-145631449.html', 0, '20 Beloved Celebrities that said Horrible Things', 'society', 0, '2016-06-28 05:39:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(822, 1, 'http://www.ctvnews.ca/business/b-c-ends-self-regulation-of-real-estate-industry-1.2967218', 0, 'B.C. ends self-regulation of real estate industry', 'society', 0, '2016-06-30 04:23:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(823, 1, 'http://www.vox.com/2016/7/1/12051622/brexit-vote-age-gap-aging-science-psychology', 0, 'Do we really become more bigoted with age? Science suggests yes', 'body', 0, '2016-07-02 01:36:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(824, 1, 'http://fivethirtyeight.com/features/poor-kids-need-summer-jobs-rich-kids-get-them/?ex_cid=story-twitter', 0, 'Poor Kids Need Summer Jobs. Rich Kids Get Them', 'society', 0, '2016-07-02 01:38:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(825, 1, 'https://www.bloomberg.com/news/articles/2016-07-01/new-study-claims-corporate-executives-intentionally-mislead-investors-for-personal-gain', 0, 'New Study Claims Corporate Executives Intentionally Mislead Investors for Personal Gain', 'society', 0, '2016-07-02 01:38:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(826, 1, 'http://www.thecerbatgem.com/joseph-c-papa-purchases-202000-shares-of-valeant-pharmaceuticals-intl-inc-vrx-stock/', 0, 'Joseph C. Papa Purchases 202,000 Shares of Valeant Pharmaceuticals Intl Inc (VRX) Stock', 'society', 0, '2016-07-02 01:52:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(827, 1, 'http://www.bbc.com/news/world-asia-36692613', 0, 'Bangladesh siege: Twenty killed at Holey Artisan Bakery in Dhaka', 'worldnhistory', 0, '2016-07-02 12:54:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(828, 1, 'https://www.thestar.com/news/crime/2016/07/01/two-dead-after-shooting-at-kensington-market-club.html', 0, 'Two dead after shooting at Kensington Market club', 'society', 0, '2016-07-02 12:57:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(829, 1, 'http://www.kelownadailycourier.ca/news/world_news/article_103139f3-30b5-5832-82b2-a7045894e6e3.html', 0, 'Italy\'s premier says Italians were among victims in Dhaka', 'worldnhistory', 0, '2016-07-02 13:00:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(830, 1, 'http://www.cbc.ca/news/politics/marijuana-legislation-knowns-unknowns-1.3660258', 0, 'Marijuana legalization in Canada: What we know and don\'t know', 'society', 0, '2016-07-02 13:01:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(831, 1, 'http://www.themarysue.com/american-woman-tried-to-kill-stephen-hawking/', 0, 'In WTF News: American Woman Arrested for Trying to Kill Stephen Hawking', 'society', 0, '2016-07-02 13:04:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(832, 1, 'http://www.dailymail.co.uk/news/article-3669610/Investigators-probe-Prince-s-doctors-claims-wrote-prescriptions-help-star-drugs-led-opioid-overdose.html', 0, 'Investigators probe Prince\'s doctors over claims they wrote prescriptions to help star get drugs', 'society', 0, '2016-07-02 13:05:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(833, 1, 'http://www.usatoday.com/story/money/2016/07/01/chipotle-quickly-distances-itself-exec-indicted-drug-charge/86605728/', 0, 'Chipotle acts quickly after exec indicted on drug charge', 'worldnhistory', 0, '2016-07-02 16:15:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(834, 1, 'http://www.cbsnews.com/news/deadly-serbia-shooting-cafe-blood-everywhere/', 0, 'Deadly Serbia shooting at cafe leaves blood everywhere, owner says', 'worldnhistory', 0, '2016-07-02 17:02:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(835, 1, 'http://www.cbsnews.com/news/deadly-serbia-shooting-cafe-blood-everywhere/', 0, 'Deadly Serbia shooting at cafe leaves blood everywhere, owner says', 'worldnhistory', 0, '2016-07-02 17:02:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(836, 1, 'http://www.cbsnews.com/news/deadly-serbia-shooting-cafe-blood-everywhere/', 0, 'Deadly Serbia shooting at cafe leaves blood everywhere, owner says', 'worldnhistory', 0, '2016-07-02 17:02:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(837, 1, 'http://science.kjzz.org/content/328124/fda-approves-first-pill-treat-all-forms-hepatitis-c', 0, 'FDA Approves First Pill To Treat All Forms Of Hepatitis C', 'scintech', 0, '2016-07-02 18:38:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(838, 1, 'http://www.winnipegfreepress.com/arts-and-life/life/health/saskatchewan-city-imposes-fee-on-businesses-selling-tobacco-products-385309941.html', 0, 'Saskatchewan city imposes fee on businesses selling tobacco products', 'society', 0, '2016-07-02 18:51:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(839, 1, 'http://www.therecord.com/news-story/6748970-anti-overdose-drug-will-be-available-in-ontario-pharmacies/', 0, 'Anti-overdose drug will be available in Ontario pharmacies', 'body', 0, '2016-07-02 19:00:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(840, 1, 'http://news.nationalpost.com/toronto/body-of-man-found-in-debris-field-of-mississauga-ont-house-explosion-identified-police', 0, 'Police identify second body found in debris field of Mississauga, Ont., house explosion', 'society', 0, '2016-07-02 19:30:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(841, 1, 'http://www.manilatimes.net/myanmar-must-end-abuses-vs-muslims/271281/', 0, 'Myanmar must end abuses vs Muslims', 'worldnhistory', 0, '2016-07-02 19:32:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(842, 1, 'http://www.narcity.com/toronto/the-top-8-most-unusual-restaurantsbars-in-toronto/', 0, 'The Top 8 Most Unusual Restaurants/Bars In Toronto', 'sexndating', 0, '2016-07-02 20:47:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(843, 1, 'https://www.buzzfeed.com/tamerragriffin/fort-pierce-cair-beating?utm_term=.gpBgdxBL7#.nirkRo9Xv', 0, 'A Man Was Beaten Outside The Same Mosque The Orlando Shooter Attended', 'society', 0, '2016-07-03 02:29:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(844, 1, 'http://www.cbc.ca/news/canada/manitoba/traigo-andretti-murderer-dead-saskatchewan-1.3662580', 0, 'Convicted murderer Traigo Andretti found dead in Saskatchewan psychiatric facility', 'society', 0, '2016-07-03 09:34:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(845, 1, 'http://montreal.ctvnews.ca/montreal-scientists-discover-new-path-for-parkinson-s-treatment-1.2970562', 0, 'Montreal scientists discover new path for Parkinson\'s treatment', 'body', 0, '2016-07-03 09:40:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(846, 1, 'https://ca.news.yahoo.com/beheaded-canadians-body-dug-southern-philippines-092646820.html', 0, 'Beheaded Canadian\'s body dug up in southern Philippines', 'worldnhistory', 0, '2016-07-03 10:44:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(847, 1, 'https://ca.news.yahoo.com/six-months-arrival-syrian-refugees-eager-jobs-country-140007438.html', 0, 'Six months after arrival, Syrian refugees eager for jobs in new country', 'worldnhistory', 0, '2016-07-03 10:46:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0);
INSERT INTO `articlelinks` (`linkid`, `linktype`, `link`, `imageid`, `title`, `category`, `articleid`, `createdate`, `revisedate`, `voteup`, `votedown`, `voteinternal`, `creatorid`, `numcomments`) VALUES
(848, 1, 'https://ca.news.yahoo.com/rare-insight-life-away-ww1-front-line-033908068.html', 0, 'Rare Insight Into Life Away From WW1 Front Line', 'worldnhistory', 0, '2016-07-03 10:47:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(849, 1, 'https://ca.news.yahoo.com/news/al-qaeda-leader-warns-gravest-consequences-boston-marathon-121304664.html', 0, 'Al Qaeda leader warns of \'gravest consequences\' if Boston bomber executed', 'society', 0, '2016-07-03 10:52:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(850, 1, 'https://ca.news.yahoo.com/news/least-82-killed-overnight-baghdad-bombings-police-medics-072344638.html', 0, 'Nearly 120 killed in overnight Baghdad bombings claimed by IS', 'worldnhistory', 0, '2016-07-03 16:54:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(851, 1, 'http://lailaalilifestyle.com/blogs/she-s-not-that-into-you-5-ways-to-tell', 0, 'She\'s Not That into You: 5 Ways to Tell  Read more: http://dailytoa.st/blogs/she-s-not-that-into-you-5-ways-to', 'sexndating', 0, '2016-07-04 05:10:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(852, 1, 'http://www.blogto.com/eat_drink/2016/03/10_ridiculously_spicy_meals_in_toronto/', 0, '10 ridiculously spicy meals in Toronto', 'worldnhistory', 0, '2016-07-04 05:11:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(853, 1, 'http://globalnews.ca/news/2801068/edmonton-man-in-hospital-after-shooting-in-texas/', 0, 'Edmonton Muslim in hospital after shooting in Texas', 'society', 0, '2016-07-04 08:08:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(854, 1, 'https://ca.news.yahoo.com/attackers-hostages-bangladesh-restaurant-173001230.html', 0, 'Hostage crisis leaves 28 dead in Bangladesh diplomatic zone', 'worldnhistory', 0, '2016-07-04 12:20:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(855, 1, 'http://www.dailymail.co.uk/wires/afp/article-3673010/Suicide-bombing-near-US-consulate-Saudi-report.html', 0, 'Suicide bombing near US consulate in Saudi\'s Jeddah', 'worldnhistory', 0, '2016-07-04 12:21:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(856, 1, 'http://www.stcatharinesstandard.ca/2016/07/04/sask-girl-16-charged-with-second-degree-murder-in-baby-boys-death', 0, 'Sask. girl, 16, charged with second-degree murder in baby boy\'s death', 'worldnhistory', 0, '2016-07-04 12:22:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(857, 1, 'http://www.pcmag.com/article/345340/how-to-get-google-to-quit-tracking-you', 0, 'How to Get Google to Quit Tracking You', 'scintech', 0, '2016-07-04 12:23:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(858, 1, 'http://www.cbc.ca/news/canada/newfoundland-labrador/canadian-blood-services-registration-1.3662760', 0, 'Canadian Blood Services launches new electronic system, promises faster donation time', 'scintech', 0, '2016-07-04 12:24:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(859, 1, 'http://www.cbc.ca/news/world/qatif-attack-1.3663735', 0, 'Explosions hit Medina, Qatif, and Jeddah in Saudi Arabia', 'worldnhistory', 0, '2016-07-05 00:21:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(860, 1, 'http://www.antifeministtech.info/2012/02/its-no-surprise-that-young-men-are-getting-fed-up-with-women-faster-than-any-other-group-of-men/', 0, 'Itâ€™s No Surprise That Young Men Are Getting Fed Up With Women Faster Than Any Other Group Of Men', 'society', 0, '2016-07-06 05:46:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(861, 1, 'http://www.bloomberg.com/news/articles/2014-04-07/manipulate-me-the-booming-business-in-behavioral-finance', 0, 'Manipulate Me: The Booming Business in Behavioral Finance', 'society', 0, '2016-07-08 07:17:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(862, 1, 'https://www.quora.com/Why-do-groups-such-as-ISIS-hate-America-Is-war-the-only-way-to-resolve-the-conflict', 0, 'Why do groups such as ISIS hate America? Is war the only way to resolve the conflict?', 'society', 0, '2016-07-08 07:32:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(863, 1, 'http://www.cbc.ca/news/politics/duffy-senate-expenses-letter-1.3670719', 0, 'Mike Duffy told to repay close to $17K of expenses despite court ruling', 'worldnhistory', 0, '2016-07-09 04:37:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(864, 1, 'http://www.cbc.ca/news/canada/newfoundland-labrador/provincial-court-judges-court-application-salary-freeze-1.3668568', 0, 'N.L. provincial court judges want pay freeze overturned', 'society', 0, '2016-07-09 04:39:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(865, 1, 'http://edition.cnn.com/2016/07/06/health/mary-todd-lincoln-pernicious-anemia/index.html', 0, 'What was behind Mary Todd Lincoln\'s bizarre behavior?', 'worldnhistory', 0, '2016-07-09 14:21:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(866, 1, 'http://qz.com/724169/an-italian-doctor-explains-syndrome-k-the-fake-disease-he-invented-to-save-jews-from-the-nazis/?utm_source=DG', 0, 'An Italian doctor explains â€œSyndrome K,â€ the fake disease he invented to save Jews from the Nazis', 'worldnhistory', 0, '2016-07-09 15:46:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(867, 1, 'http://nymag.com/daily/intelligencer/2016/07/six-more-women-allege-ailes-sexual-harassment.html?mid=nymag_press#', 0, 'Six More Women Allege That Roger Ailes Sexually Harassed Them', 'society', 0, '2016-07-09 18:36:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(868, 1, 'http://www.independent.co.uk/news/uk/do-your-genes-make-you-a-criminal-1572714.html', 0, 'Do your genes make you a criminal?', 'society', 0, '2016-07-10 02:31:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(869, 1, 'http://www.allthingscrimeblog.com/2014/05/11/51-best-disturbing-quotes-from-19-disturbed-serial-killers/', 0, 'Top 51 Disturbing Quotes from 19 Disturbed Serial Killers', 'society', 0, '2016-07-10 02:32:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(870, 1, 'http://www.mcclatchydc.com/news/politics-government/article24749413.html', 0, 'Marijuana is drug most often linked to crime, study finds', 'general', 0, '2016-07-10 12:11:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(871, 1, 'https://www.thrillist.com/eat/nation/how-i-learned-more-working-in-a-restaurant-than-i-did-in-college', 0, 'HOW I LEARNED MORE WORKING IN A RESTAURANT THAN I DID IN COLLEGE', 'society', 0, '2016-07-10 12:12:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(872, 1, 'http://www.dailymail.co.uk/news/article-3159344/There-s-no-jail-big-midget-Mexico-s-billion-dollar-drugs-lord-gloats-Twitter-escaping-prison-shower-block-tunnel.html', 0, 'Mexican Drug Lord Threatens Donald Trump', 'worldnhistory', 0, '2016-07-11 03:22:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(873, 1, 'http://www.nytimes.com/2016/07/10/upshot/a-medical-mystery-of-the-best-kind-major-diseases-are-in-decline.html?_r=0', 0, 'A Medical Mystery of the Best Kind: Major Diseases Are in Decline', 'worldnhistory', 0, '2016-07-11 11:08:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(874, 1, 'http://www.nytimes.com/2016/07/10/sports/youth-sports-embezzlement-by-adults.html?_r=0', 0, 'The Trusted Grown-Ups Who Steal Millions From Youth Sports', 'society', 0, '2016-07-11 11:25:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(875, 1, 'https://www.theguardian.com/us-news/2016/jul/11/san-diego-homeless-killing-spree-suspect-released', 0, 'San Diego police still searching for suspected serial killer of homeless', 'society', 0, '2016-07-12 06:02:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(876, 1, 'https://ca.news.yahoo.com/bin-ladens-son-threatens-revenge-fathers-assassination-monitor-092033042.html', 0, 'Bin Laden\'s son threatens revenge for father\'s assassination: monitor', 'society', 0, '2016-07-12 07:28:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(877, 1, 'http://www.eater.com/2016/7/8/12131744/3d-printing-pop-up-food-ink', 0, 'Everything Is 3D Printed at London\'s Next Pop-Up Restaurant', 'scintech', 0, '2016-07-12 07:31:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(878, 1, 'https://timeline.com/iconic-photos-political-protest-81c5701f9695#.fvkpkrqhu', 0, '10 of the most iconic protest photos', 'society', 0, '2016-07-13 02:18:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(879, 1, 'http://www.inc.com/lisa-calhoun/meet-the-first-artificial-animal.html', 0, 'Scientists Create Successful Biohybrid Being Using 3-D Printing and Genetic Engineering', 'scintech', 0, '2016-07-13 04:13:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(880, 1, 'http://www.theglobeandmail.com/news/national/ontario-doctor-group-disappointed-in-deal-between-oma-province/article30882873/', 0, 'Ontario, OMA agree to clamp down on high-billing doctors', 'society', 0, '2016-07-13 10:00:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(881, 1, 'http://digg.com/video/why-college-expensive', 0, 'Why Is College So Insanely Expensive In The US?', 'society', 0, '2016-07-13 10:16:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(882, 1, 'https://ca.finance.yahoo.com/blogs/insight/think-you-cant-afford-to-invest-in-real-estate-152029844.html', 0, 'Think you canâ€™t afford to invest in real estate? Think again', 'general', 0, '2016-07-15 11:54:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(883, 1, 'https://ca.finance.yahoo.com/news/keralites-mixed-bag-govt-move-impose-tax-junk-115718604.html', 0, 'Indian state introduces \'fat tax\' to curb obesity', 'worldnhistory', 0, '2016-07-15 11:58:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(884, 1, 'https://ca.news.yahoo.com/world-reacts-horrific-terror-attack-nice-044000091.html', 0, 'World Reacts To \'Horrific Terror Attack\' In Nice', 'worldnhistory', 0, '2016-07-15 11:58:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(885, 1, 'http://www.cbc.ca/news/canada/manitoba/body-of-teen-missing-from-rhineland-found-1.3682298', 0, 'Body of teen who disappeared swimming in southern Manitoba found, RCMP say', 'worldnhistory', 0, '2016-07-16 18:36:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(886, 1, 'http://www.cbc.ca/news/canada/british-columbia/vancouver-real-estate-crackdown-tax-cheats-south-china-morning-post-1.3681632', 0, 'CRA leak about crackdown on B.C. real estate tax cheats heats debate', 'society', 0, '2016-07-16 18:40:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(887, 1, 'http://www.torontosun.com/2016/07/16/taylor-swift-to-face-alleged-groper-in-court', 0, 'Taylor Swift to face alleged groper in court', 'worldnhistory', 0, '2016-07-16 18:41:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(888, 1, 'https://ca.news.yahoo.com/officials-man-shoots-pokemon-players-outside-house-030859087.html', 0, 'Officials: Man shoots at \'Pokemon Go\' players outside house', 'society', 0, '2016-07-17 19:00:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(889, 1, 'http://torontolife.com/city/crime/toronto-police-service-vs-everybody/', 0, 'Torontoâ€™s cops are overpaid, underworked, deeply entrenched and all too powerful.', 'society', 0, '2016-07-17 19:39:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(890, 1, 'https://ca.news.yahoo.com/documents-pulse-gunman-repeatedly-taunted-being-muslim-204430358.html', 0, 'Pulse gunman repeatedly taunted for being Muslim', 'society', 0, '2016-07-19 04:46:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(891, 1, 'http://www.businessinsider.com/trump-is-appealing-because-hes-rich-2016-6', 0, 'Trump is appealing because he is rich', 'worldnhistory', 0, '2016-07-22 06:00:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(892, 1, 'https://www.youtube.com/watch?v=OJ97gEFBH5k', 0, 'Ex-KKK Leader David Duke\'s Senate Campaign Announcement Video Is Scary', 'worldnhistory', 0, '2016-07-23 07:02:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(893, 1, 'http://www.amren.com/news/2015/07/new-doj-statistics-on-race-and-violent-crime/', 0, 'New DOJ Statistics on Race and Violent Crime', 'society', 0, '2016-07-23 14:33:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(894, 1, 'http://www.irishtimes.com/news/world/europe/munich-shooting-teen-who-killed-nine-had-no-isis-links-1.2732672', 0, 'Munich shooting: Teen who killed nine â€˜had no Isis links\'', 'worldnhistory', 0, '2016-07-23 14:48:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(895, 1, 'http://www.torontosun.com/2016/07/23/fergie-hints-kim-kardashians-taylor-swift-feud-is-a-publicity-stunt', 0, 'Fergie hints Kim Kardashian\'s Taylor Swift feud is a publicity stunt', 'society', 0, '2016-07-23 16:03:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(896, 1, 'https://www.one.org/us/2015/02/12/8-people-who-broke-the-law-to-change-the-world/', 0, '8 people who broke the law to change the world', 'worldnhistory', 0, '2016-07-27 08:34:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(897, 1, 'http://www.lifehack.org/306812/6-reasons-why-rebellious-kids-turn-out-more-successful', 0, '6 Reasons Why Rebellious Kids Turn Out To Be More Successful', 'society', 0, '2016-07-27 08:35:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(898, 1, 'https://itxdesign.com/why-people-who-break-the-rules-have-higher-incomes/', 0, 'Why People Who Break the Rules Have Higher Incomes', 'society', 0, '2016-07-27 08:36:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(899, 1, 'https://www.psychologytoday.com/blog/the-situation-lab/201509/the-personality-donald-trump', 0, 'The Personality of Donald Trump', 'society', 0, '2016-07-27 08:59:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(900, 1, 'https://ca.finance.yahoo.com/news/higher-education-still-worth-money-140829504.html', 0, 'Higher education still worth the money, new research suggests', 'society', 0, '2016-07-27 21:28:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(901, 1, 'https://ca.news.yahoo.com/scientists-release-air-trapped-800-151803417.html', 0, 'Scientists Release Air Trapped 800 Million Years Ago', 'worldnhistory', 0, '2016-07-27 23:57:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(902, 1, 'https://ca.news.yahoo.com/young-man-stands-racist-woman-130509576.html', 0, 'Young man heroically stands up to racist woman', 'society', 0, '2016-07-28 00:00:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(903, 1, 'https://ca.news.yahoo.com/body-found-whitefish-lake-first-181200164.html?nhp=1', 0, 'Deaths of two First Nation teens could be \'foul play,\' RCMP say', 'society', 0, '2016-07-28 00:02:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(904, 1, 'https://ca.news.yahoo.com/john-hinckley-jr-shot-ronald-134045212.html', 0, 'John Hinckley Jr., Who Shot Ronald Reagan, Granted Full-Time Release From Mental Hospital', 'society', 0, '2016-07-28 00:03:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(905, 1, 'https://www.psychologytoday.com/blog/busting-myths-about-human-nature/201204/bad-the-bone-are-humans-naturally-aggressive', 0, 'Bad to the Bone: Are Humans Naturally Aggressive?', 'society', 0, '2016-07-31 15:43:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(906, 1, 'http://www.cbc.ca/news/canada/toronto/shooting-yonge-dundas-1.3702379', 0, 'Shooting near Yonge and Dundas leaves 2 injured', 'society', 0, '2016-07-31 15:58:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(907, 1, 'http://www.cbc.ca/news/canada/toronto/man-with-knife-on-ttc-bus-apprehended-after-5-hours-of-negotiation-1.3702249', 0, 'Man with knife on TTC bus apprehended after 5 hours of negotiation', 'society', 0, '2016-07-31 15:59:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(908, 1, 'http://www.scientificamerican.com/article/research-casts-doubt-on-the-value-of-acupuncture/', 0, 'Research Casts Doubt on the Value of Acupuncture', 'scintech', 0, '2016-08-01 05:12:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(909, 1, 'http://qz.com/747595/millennials-are-smart-to-distrust-their-employers-and-their-schools/', 0, 'Millennials are smart to distrust their employers and their schools', 'society', 0, '2016-08-03 03:41:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(910, 1, 'http://www.cbc.ca/news/world/brazil-president-trial-1.3707360', 0, 'Brazil Senate committee votes to put president on trial', 'worldnhistory', 0, '2016-08-05 05:40:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(911, 1, 'http://www.theglobeandmail.com/news/politics/defence-minister-to-visit-drc-on-mission-to-learn-about-peacekeeping/article31277571/', 0, 'Defence Minister to tour Africa on mission to learn about peacekeeping', 'society', 0, '2016-08-05 05:41:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(912, 1, 'http://www.570news.com/2016/08/04/apple-to-offer-cash-for-reporting-security-flaws/', 0, 'Apple to offer cash for reporting security flaws', 'scintech', 0, '2016-08-05 05:42:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(913, 1, 'http://graphics.wsj.com/armchair-olympian/track/', 0, 'Play a minigame to test your reaction time', 'scintech', 0, '2016-08-07 13:39:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(914, 1, 'https://ca.finance.yahoo.com/news/facebook-investing-stock-market-opportunities-000000079.html', 0, '34-year-old Facebook employee sees better investing opportunities than stocks', 'scintech', 0, '2016-08-13 16:52:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(915, 1, 'http://www.cbc.ca/news/canada/toronto/doctors-vote-not-to-accept-ontario-government-s-proposed-fee-agreement-1.3722071', 0, 'Doctors vote not to accept Ontario government\'s proposed fee agreement', 'society', 0, '2016-08-15 23:04:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(916, 1, 'http://www.cbc.ca/news/politics/philpott-ground-transportation-1700-bill-1.3725211', 0, 'Health Minister Jane Philpott should repay $1,700 transportation bill, Tories say', 'society', 0, '2016-08-18 03:56:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(917, 1, 'http://www.genocidewatch.org/aboutgenocide/8stagesofgenocide.html', 0, 'The 8 Stages of Genocide', 'worldnhistory', 0, '2016-08-22 06:38:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(918, 1, 'http://www.theglobeandmail.com/news/national/more-federal-funds-needed-to-deal-with-aging-populations-health-costs-cma/article31484696/', 0, 'More federal funds needed to deal with aging populationâ€™s health costs: CMA', 'society', 0, '2016-08-22 06:44:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(919, 1, 'http://www.cbc.ca/news/canada/hamilton/news/hamilton-s-top-10-public-salary-earners-of-2013-1.2590455', 0, 'Hamilton\'s top 10 public salary earners of 2013', 'society', 0, '2016-08-22 12:07:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(920, 1, 'https://www.engadget.com/2016/08/24/dexmo-exoskeleton-glove-force-feedback/', 0, 'Dexmo exoskeleton glove lets you touch and feel in VR', 'scintech', 0, '2016-08-26 11:16:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(921, 1, 'https://ca.news.yahoo.com/news/why-areas-more-men-higher-marriage-rates-150958793.html', 0, 'Why Areas with More Men Have Higher Marriage Rates', 'society', 0, '2016-08-26 23:52:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(922, 1, 'http://www.nature.com/news/beyond-terminator-squishy-octobot-heralds-new-era-of-soft-robotics-1.20487', 0, 'Beyond Terminator: squishy \'octobot\' heralds new era of soft robotics', 'scintech', 0, '2016-08-27 12:17:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(923, 1, 'http://www.inc.com/nicolas-cole/7-things-selfish-people-do-in-the-workplace.html', 0, '7 Things Selfish People Do In The Workplace', 'society', 0, '2016-08-28 00:09:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(924, 1, 'http://www.dailymail.co.uk/sciencetech/article-2889942/Do-violent-criminals-believe-doing-right-thing-murderers-morally-motivated-claims-controversial-study.html', 0, 'Do violent criminals believe they are doing the right thing?', 'society', 0, '2016-08-28 07:31:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(925, 1, 'http://www.vocativ.com/351406/a-guide-book-for-faking-your-own-death-in-the-digital-age/', 0, 'A Guide Book For Faking Your Own Death In The Digital Age', 'society', 0, '2016-08-29 01:27:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(926, 1, 'http://www.nytimes.com/2016/08/29/world/europe/russia-sweden-disinformation.html?_r=0', 0, 'A Powerful Russian Weapon: The Spread of False Stories', 'worldnhistory', 0, '2016-08-29 01:30:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(927, 1, 'http://www.nature.com/news/majority-of-mathematicians-hail-from-just-24-scientific-families-1.20491', 0, 'Majority of mathematicians hail from just 24 scientific â€˜familiesâ€™', 'scintech', 0, '2016-08-29 01:34:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(928, 1, 'http://boredbug.com/heres-proof-world-changed-lot-last-50-years/', 0, 'Hereâ€™s Proof The World Has Changed A Lot In The Last 50 Years', 'worldnhistory', 0, '2016-08-29 01:57:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(929, 1, 'http://gizmodo.com/year-long-simulation-of-humans-living-on-mars-comes-to-1785865918', 0, 'Year-Long Simulation of Humans Living on Mars Comes To an End', 'scintech', 0, '2016-08-29 05:01:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(930, 1, 'https://ca.news.yahoo.com/stephen-harper-says-goodbye-and-resigns-as-mp-163228382.html', 0, 'Stephen Harper says goodbye and resigns as MP', 'worldnhistory', 0, '2016-08-29 05:27:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(931, 1, 'http://www.cbc.ca/news/politics/sexual-misconduct-military-punished-1.3741493', 0, '30 Canadian Forces members punished for sexual misconduct, 97 cases ongoing', 'society', 0, '2016-08-31 11:11:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(932, 1, 'http://bigthink.com/paul-ratner/a-new-unifying-equation-promises-to-transform-physics-with-the-help-of-wormholes?utm_campaign=Echobox&utm_medium=Social&utm_source=Twitter#link_time=1472594114', 0, 'This New Equation Promises to Unify Physics Theories with the Help of Wormholes', 'scintech', 0, '2016-08-31 22:09:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(933, 1, 'http://qz.com/761000/its-not-just-you-time-really-does-seem-to-fly-by-faster-as-we-age/', 0, 'Itâ€™s not just you. Time really does seem to fly by faster as we age', 'body', 0, '2016-09-03 11:57:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(934, 1, 'http://www.cbc.ca/news/canada/british-columbia/ubc-research-fasd-1.3747981', 0, 'UBC-led researchers uncover genetic effects of FASD', 'scintech', 0, '2016-09-04 16:59:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(935, 1, 'http://www.nbcnews.com/storyline/zika-virus-outbreak/zika-count-rises-189-singapore-n642141', 0, 'Zika Count Rises to 215 in Singapore', 'worldnhistory', 0, '2016-09-04 17:00:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(936, 1, 'https://thinkprogress.org/us-china-to-formally-join-paris-agreement-b638ba9c2f9b#.qlne5vw0b', 0, 'The Worldâ€™s Biggest Carbon Emitters Officially Join The Paris Climate Deal (Updated)', 'worldnhistory', 0, '2016-09-04 17:01:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(937, 1, 'http://www.extremetech.com/extreme/234808-why-are-we-still-using-lame-lithium-ion-batteries-after-so-many-promising-alternatives', 0, 'Why are we still using lame lithium-ion batteries after so many promising alternatives?', 'scintech', 0, '2016-09-04 17:02:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(938, 1, 'http://www.informationweek.com/mobile/enterprise-mobility-management/smartphone-market-sees-dramatic-decline-in-2016-/d/d-id/1326811', 0, 'Smartphone Market Sees Dramatic Decline In 2016', 'scintech', 0, '2016-09-04 17:03:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(939, 1, 'http://www.ctvnews.ca/politics/ambrose-doesn-t-support-the-idea-behind-leitch-s-immigrant-screening-proposal-1.3057958', 0, 'Ambrose \'doesn\'t support the idea\' behind Leitch\'s immigrant screening proposal', 'society', 0, '2016-09-04 17:04:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(940, 1, 'https://www.theguardian.com/world/2016/sep/04/barack-obama-deliberately-snubbed-by-chinese-in-chaotic-arrival-at-g20', 0, 'Barack Obama \'deliberately snubbed\' by Chinese in chaotic arrival at G20', 'worldnhistory', 0, '2016-09-04 22:07:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(941, 1, 'http://www.bloomberg.com/news/articles/2016-09-01/teachers-face-a-17-percent-pay-cut-when-they-join-the-noble-profession', 0, 'Teachers Face a 17 Percent Pay Cut When They Join the Noble Profession', 'society', 0, '2016-09-05 20:17:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(942, 1, 'http://www.newsweek.com/2016/09/16/9-11-death-toll-rising-496214.html', 0, '9/11â€™S SECOND WAVE: CANCER AND OTHER DISEASES LINKED TO THE 2001 ATTACKS ARE SURGING', 'worldnhistory', 0, '2016-09-08 11:37:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(943, 1, 'http://www.ctvnews.ca/health/private-health-care-would-prioritize-profit-over-patients-lawyer-1.3073049', 0, 'Private health care would prioritize profit over patients: lawyer', 'society', 0, '2016-09-15 11:55:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(944, 1, 'http://motherboard.vice.com/read/the-girl-who-would-live-forever', 0, 'Cryonics and the Girl Who Will Live Forever', 'general', 0, '2016-09-17 16:59:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(945, 1, 'http://www.investopedia.com/video/play/john-mcafee-antivirus-software-dao-hacks-ashley-madison/?utm_campaign=www.investopedia.com&utm_source=market-sum&utm_term=7663415&utm_medium=email', 0, 'John McAfee on Anti-Virus Software, DAO Hacks & Ashley Madison', 'scintech', 0, '2016-09-20 10:05:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(946, 1, 'http://digg.com/video/decoding-mind-marvin-chun', 0, 'Scientists Can Reconstruct An Image Of What Someone Was Looking At Using Brain Scans', 'scintech', 0, '2016-09-23 00:32:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(947, 1, 'http://indianexpress.com/article/india/india-news-india/bahama-leaks-black-money-tax-evasion-after-panama-papers-bahamas-indians-in-the-list-3043106/', 0, 'After Panama Papers, Bahamas: More Indians in secret tax haven list', 'society', 0, '2016-09-23 09:51:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(948, 1, 'https://ca.news.yahoo.com/trudeau-aides-butts-telford-expensed-034341052.html', 0, 'Top two PMO aides apologize for controversy over moving expenses', 'society', 0, '2016-09-23 10:02:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(949, 1, 'http://www.cbc.ca/news/canada/ottawa/ottawa-hospital-exec-salaries-disclosed-1.1180570', 0, 'Ottawa hospital exec salaries disclosed', 'society', 0, '2016-09-24 02:47:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(950, 1, 'https://www.buzzfeed.com/mollyhensleyclancy/the-industry-that-was-crushed-by-the-obama-administration?utm_term=.igl3L5qOW#.lxpPGpDM0', 0, 'The Industry That Was Crushed By The Obama Administration', 'worldnhistory', 0, '2016-09-25 18:11:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(951, 1, 'http://fusion.net/story/349359/cops-and-ip-addresses/', 0, 'Cops are raiding the homes of innocent people based only on IP addresses', 'society', 0, '2016-09-25 18:12:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(952, 1, 'http://www.nature.com/news/science-s-1-how-income-inequality-is-getting-worse-in-research-1.20651', 0, 'Scienceâ€™s 1%: How income inequality is getting worse in research', 'society', 0, '2016-09-25 18:52:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(953, 1, 'https://www.wired.com/2016/09/rogue-doctors-spreading-right-wing-rumors-hillarys-health/?mbid=synd_digg', 0, 'The Rogue Doctors Spreading Right-Wing Rumors About Hillaryâ€™s Health', 'society', 0, '2016-09-26 05:12:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(954, 1, 'http://ca.askmen.com/top_10/dating/top-10-stupid-things-guys-do-to-impress-girls.html', 0, 'Top 10: Stupid Things Guys Do To Impress Girls', 'sexndating', 0, '2016-09-28 01:46:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(955, 1, 'https://www.bloomberg.com/view/articles/2016-09-28/health-care-costs-ate-your-pay-raises', 0, 'Health-Care Costs Ate Your Pay Raises', 'society', 0, '2016-09-29 20:57:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(956, 1, 'http://www.thememo.com/2016/09/27/oberthur-technologies-societe-generale-groupe-bpce-bank-this-high-tech-card-is-being-rolled-out-by-french-banks-to-eliminate-fraud/', 0, 'This high-tech card is being rolled out by French banks to eliminate fraud', 'scintech', 0, '2016-10-02 20:39:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(957, 1, 'http://bigstory.ap.org/article/8fb0819e3b6543788237f32070f73974/business-owner-2-firms-face-visa-fraud-charges', 0, 'Business owner, 2 firms face H1B visa fraud charges', 'society', 0, '2016-10-02 20:49:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(958, 1, 'http://arstechnica.com/science/2016/08/rage-mounts-against-pharma-corp-that-jacked-cost-of-life-saving-epipen-by-400/', 0, 'Rage mounts against pharma corp. that jacked cost of life-saving EpiPen by 400%', 'society', 0, '2016-10-02 20:52:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(959, 1, 'http://www.sciencemag.org/news/2016/09/print-demand-bone-could-quickly-mend-major-injuries', 0, 'Print-on-demand bone could quickly mend major injuries', 'scintech', 0, '2016-10-02 20:54:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(960, 1, 'https://www.washingtonpost.com/graphics/business/batteries/congo-cobalt-mining-for-lithium-ion-battery/', 0, 'Cobalt - From The Mines To Your Electronics', 'worldnhistory', 0, '2016-10-03 01:46:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(961, 1, 'http://www.theatlantic.com/science/archive/2016/09/humans-are-unusually-violent-mammals-but-averagely-violent-primates/501935/', 0, 'Humans: Unusually Murderous Mammals, Typically Murderous Primates', 'scintech', 0, '2016-10-03 02:27:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(962, 1, 'https://www.thestar.com/news/gta/2015/05/17/ontario-allowing-employers-to-fire-workers-without-cause.html', 0, 'Ontario allowing employers to fire workers without cause', 'society', 0, '2016-10-03 05:10:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(963, 1, 'http://www.forbes.com/sites/freekvermeulen/2011/04/22/criminals-are-ugly-yes-really/#d1d43b8518e5', 0, 'Criminals are ugly - yes, really', 'society', 0, '2016-10-03 05:23:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(964, 1, 'http://ca.askmen.com/top_10/entertainment/10-habits-of-successful-criminals_10.html', 0, '10 habits of successful criminals', 'society', 0, '2016-10-03 05:25:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(965, 1, 'http://www.cbc.ca/news/canada/saskatchewan/merchant-law-group-accused-fraud-canadian-government-1.3791417', 0, 'Canadian government claims residential school lawyer committed fraud over fees', 'society', 0, '2016-10-05 11:30:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(966, 1, 'http://www.theglobeandmail.com/life/health-and-fitness/health/why-starbucks-canadas-investment-in-mental-health-therapy-matters/article32252755/', 0, 'Why Starbucks Canada\'s investment in mental health therapy matters', 'society', 0, '2016-10-05 11:57:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(967, 1, 'https://www.thestar.com/news/gta/2016/10/05/basic-income-no-silver-bullet-against-poverty-report-says.html', 0, 'Basic income, no silver bullet against poverty, report says', 'society', 0, '2016-10-05 11:58:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(968, 1, 'http://www.cbc.ca/news/business/mortgage-rules-shadow-banking-1.3791244', 0, 'Mortgage rule changes could lead to growth in shadow banking: experts', 'society', 0, '2016-10-05 11:59:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(969, 1, 'http://www.cbc.ca/news/world/poland-abortion-law-1.3789335', 0, 'Poland\'s proposed ban on abortion part of broader push to turn back history', 'worldnhistory', 0, '2016-10-05 12:00:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(970, 1, 'http://news.nationalpost.com/news/world/trump-backers-realize-theyve-been-played-as-wikileaks-fails-to-come-through-with-bombshells-about-clinton', 0, 'Trump team realizes itâ€™s been played as WikiLeaks fails to come through with bombshells about Clinton', 'society', 0, '2016-10-05 12:00:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(971, 1, 'http://www.theatlantic.com/science/archive/2016/10/the-psychology-of-victim-blaming/502661/', 0, 'The Psychology of Victim-Blaming', 'society', 0, '2016-10-06 11:34:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(972, 1, 'http://www.nytimes.com/2016/10/07/upshot/your-surgeon-is-probably-a-republican-your-psychiatrist-probably-a-democrat.html', 0, 'Your Surgeon Is Probably A Republican, Your Psychiatrist Is Probably A Democrat', 'society', 0, '2016-10-06 23:59:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(973, 1, 'https://ca.finance.yahoo.com/news/nortel-executives-continue-drawing-bonuses-090000284.html', 0, 'Nortel executives continue drawing bonuses years after bankruptcy', 'society', 0, '2016-10-08 11:25:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(974, 1, 'http://rabble.ca/blogs/bloggers/nora-loreto/2016/10/cineplex-hikes-ticket-prices-pursuit-record-profits-blames-its-lo', 0, 'Cineplex hikes ticket prices in pursuit of record profits, blames its low-waged workers', 'society', 0, '2016-10-08 13:35:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(975, 1, 'https://www.glassdoor.com/research/ceo-pay-ratio/', 0, 'CEO to Worker Pay Ratios: Average CEO Earns 204 Times Median Worker Pay', 'society', 0, '2016-10-08 15:07:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(976, 1, 'https://www.higheredjobs.com/salary/salaryDisplay.cfm?SurveyID=1', 0, 'Senior-Level Administrator Median Salaries by Title and Institution Type (2005-06)', 'society', 0, '2016-10-08 15:08:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(977, 1, 'http://www.theglobeandmail.com/news/world/how-six-key-voting-groups-will-be-affected-by-trumps-lewdness/article32310454/', 0, 'How six key voting groups will be affected by Trumpâ€™s lewdness', 'society', 0, '2016-10-08 17:11:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(978, 1, 'http://motherboard.vice.com/read/can-slim-peoples-poop-treat-obesity', 0, 'Can Slim Peopleâ€™s Poop Treat Obesity?', 'scintech', 0, '2016-10-09 14:20:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(979, 1, 'https://features.wearemel.com/these-guys-will-do-anything-to-avoid-coming-279fc4eb1a8b#.7tu10g641', 0, 'When an Orgasm Can Destroy Your Life', 'sexndating', 0, '2016-10-09 14:46:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(980, 1, 'http://mentalfloss.com/article/87238/what-school-lunch-looked-each-decade-past-century', 0, 'What School Lunch Looked Like Each Decade for the Past Century', 'worldnhistory', 0, '2016-10-14 10:56:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(981, 1, 'https://ca.news.yahoo.com/thailands-king-worlds-longest-reigning-120521020.html', 0, 'Thailand\'s revered king dies after 70 years on throne', 'worldnhistory', 0, '2016-10-14 10:57:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(982, 1, 'http://www.embracepossibility.com/blog/why-old-people-have-a-hard-time-learning-new-things/', 0, 'Why Old People Have a Hard Time Learning New Things', 'scintech', 0, '2016-10-16 14:32:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(983, 1, 'http://money.cnn.com/2016/10/18/investing/wells-fargo-warned-fake-accounts-2007/', 0, 'Letter warned Wells Fargo of \'widespread\' fraud in 2007 - exclusive', 'society', 0, '2016-10-18 23:54:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(984, 1, 'https://www.wired.com/2007/07/anyone-can-buil/', 0, 'Anyone Can Build a Dirty Bomb', 'scintech', 0, '2016-10-25 04:57:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(985, 1, 'http://www.theverge.com/2016/10/24/13383616/bone-conduction-headphones-best-pair-aftershokz', 0, 'Are bone conduction headphones good enough yet?', 'scintech', 0, '2016-10-25 05:02:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(986, 1, 'http://digg.com/video/planned-obsolescence-adhd-animation-song', 0, 'Why Companies Plan For Your Device\'s Untimely Death', 'scintech', 0, '2016-10-29 13:18:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(987, 1, 'http://digg.com/video/edison-last-breath', 0, 'This Glass Vial Holds Edison\'s Last Breath', 'worldnhistory', 0, '2016-10-29 13:23:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(988, 1, 'http://www.ctvnews.ca/world/man-in-chained-woman-case-faces-murder-charges-1.3148082', 0, 'Man in chained woman case faces murder charges', 'society', 0, '2016-11-06 17:51:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(989, 1, 'https://www.washingtonpost.com/national/health-science/first-year-doctors-would-be-allowed-to-work-24-hour-shifts-under-new-rules/2016/11/04/c1b928c2-a282-11e6-8832-23a007c77bb4_story.html', 0, 'First-year doctors would be allowed to work 24-hour shifts under new rules', 'society', 0, '2016-11-07 10:58:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(990, 1, 'http://www.cbc.ca/news/canada/toronto/police-exchange-zone-1.3839746', 0, 'Police \'exchange zone\' aims to curb fraud, robberies from online deals', 'society', 0, '2016-11-08 12:11:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(991, 1, 'http://www.cbc.ca/news/canada/toronto/indian-rupee-canada-worthless-cash-1.3846942', 0, 'Indian rupee cancellation leaves some Toronto residents with worthless cash', 'worldnhistory', 0, '2016-11-11 15:12:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(992, 1, 'https://www.thestar.com/news/world/2016/11/11/trump-sparks-climate-worries-emboldens-forces-of-hate-senate-minority-leader-says.html', 0, 'Senate Minority leader Harry Reid lashes out; â€˜Trump emboldens forces of hate, bigotryâ€™', 'worldnhistory', 0, '2016-11-11 23:58:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(993, 1, 'http://www.macleans.ca/economy/business/the-new-upper-class/', 0, 'The $100,000 club: Whoâ€™s really making big money these days', 'society', 0, '2016-11-14 06:11:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(994, 1, 'http://www.cbc.ca/news/health/private-drug-insurance-up-1.3845301', 0, 'Get ready to pay more for private drug plans', 'society', 0, '2016-11-14 12:49:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(995, 1, 'http://www.cbc.ca/news/canada/toronto/man-charged-in-leaside-woman-s-homicide-1.1257006', 0, 'Man charged in Leaside woman\'s homicide', 'society', 0, '2016-11-18 03:14:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(996, 1, 'http://www.foxnews.com/story/2008/07/30/woman-with-ties-to-white-supremacists-represents-school-for-blacks-and.html', 0, 'Woman With Ties to White Supremacists Represents School for Blacks and Hispanics', 'society', 0, '2016-11-19 14:23:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(997, 1, 'http://www.amusingplanet.com/2016/11/the-sponge-divers-of-greece.html', 0, 'The Sponge Divers of Greece', 'scintech', 0, '2016-11-29 15:04:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(998, 1, 'http://www.ctvnews.ca/health/so-called-smart-drugs-all-the-rage-on-college-campuses-but-do-they-work-1.3181470?autoPlay=true', 0, 'So-called smart drugs \'all the rage\' on college campuses but do they work?', 'scintech', 0, '2016-11-29 16:05:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(999, 1, 'https://www.washingtonpost.com/news/worldviews/wp/2016/11/28/fidel-castro-african-hero/', 0, 'Fidel Castro, African hero', 'society', 0, '2016-11-29 17:10:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1000, 1, 'http://www.forbes.com/sites/realspin/2016/11/29/thanks-to-fight-for-15-minimum-wage-mcdonalds-unveils-job-replacing-self-service-kiosks-nationwide/#24f1f542762e', 0, 'Thanks To \'Fight For $15\' Minimum Wage, McDonald\'s Unveils Job-Replacing Self-Service Kiosks Nationwide', 'society', 0, '2016-12-04 17:47:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1001, 1, 'http://digg.com/video/world-fact-video', 0, 'An Interesting Fact About Every Country In The World', 'worldnhistory', 0, '2016-12-07 06:10:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1002, 1, 'http://www.forbes.com/sites/ryanmac/2016/03/30/square-ecommerce-api-stripe-paypal/#66dc91613434', 0, 'Square On Collision Course With Stripe And PayPal After Unveiling New Service', 'scintech', 0, '2016-12-12 03:56:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1003, 1, 'http://www.ctvnews.ca/health/new-weight-loss-pill-like-an-imaginary-meal-1.2174836', 0, 'New weight loss pill \'like an imaginary meal\'', 'scintech', 0, '2016-12-13 23:12:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1004, 1, 'http://www.theglobeandmail.com/globe-investor/investment-ideas/prem-watsa-dumps-90-of-us-long-bond-holdings-ahead-of-election/article32679309/', 0, 'Prem Watsa dumps 90% of U.S. long-bond holdings ahead of election', 'society', 0, '2016-12-19 04:39:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1005, 1, 'https://youtu.be/hP-DZMmQBng', 0, 'A Young Savant\'s Clever Way To Visualize Numbers As Shapes', 'scintech', 0, '2016-12-20 01:31:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1006, 1, 'https://youtu.be/brE21SBO2j8', 0, 'SpaceX Makes History | MARS', 'scintech', 0, '2016-12-21 05:06:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1007, 1, 'http://www.cbc.ca/news/canada/toronto/york-police-fraud-30-million-1.3906562', 0, 'York police lay 42 charges in $30 million fraud investigation', 'society', 0, '2016-12-21 15:25:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1008, 1, 'http://www.livescience.com/57271-mouthwash-may-kill-gonorrhea-bacteria.html', 0, 'Mouthwash May Kill Gonorrhea Bacteria', 'scintech', 0, '2016-12-22 19:09:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1009, 1, 'https://www.wired.com/2016/12/amazons-real-future-isnt-drones-self-driving-trucks/?mbid=synd_digg', 0, 'Amazonâ€™s Real Future Isnâ€™t Drones. Itâ€™s Self-Driving Trucks', 'scintech', 0, '2016-12-23 11:10:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1010, 1, 'https://www.bloomberg.com/news/articles/2016-12-23/deutsche-bank-credit-suisse-settle-u-s-probes-as-barclays-sued', 0, 'Deutsche Bank, Credit Suisse Settle U.S. Subprime Probes', 'worldnhistory', 0, '2016-12-24 00:12:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1011, 1, 'https://www.theguardian.com/us-news/2016/dec/22/nseers-arab-muslim-tracking-system-dismantled-obama', 0, 'Registry used to track Arabs and Muslims dismantled by Obama administration', 'worldnhistory', 0, '2016-12-25 02:10:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1017, 1, 'http://overflow.solutions/demographic-data/age-distributions/how-many-times-have-americans-been-married-by-age/', 0, 'Time Americans Have Been Married By Age', 'society', 0, '2016-12-27 14:35:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1016, 1, 'http://cosmos.nautil.us/short/85/the-argument-against-terraforming-mars', 0, 'The Argument Against Terraforming Mars', 'scintech', 0, '2016-12-27 10:23:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1018, 1, 'http://cosmos.nautil.us/short/86/maybe-we-havent-seen-any-aliens-because-theyre-all-dead', 0, 'Maybe We Havenâ€™t Seen Any Aliens Because Theyâ€™re All Dead', 'scintech', 0, '2016-12-29 04:48:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1019, 1, 'http://bigstory.ap.org/article/9ccb9a5ab1394a168db8b8362d94790d', 0, 'US senators: Russia should be sanctioned for election hacks', 'worldnhistory', 0, '2016-12-29 13:25:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1020, 1, 'http://www.latimes.com/projects/la-me-el-monte-pensions/', 0, 'When city retirement pays better than the job', 'society', 0, '2017-01-03 10:09:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1021, 1, 'http://www.computerworld.com/article/2914233/it-careers/median-age-at-google-is-29-says-age-discrimination-lawsuit.html', 0, 'Median age at Google is 29, says age discrimination lawsuit', 'society', 0, '2017-01-05 14:25:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1022, 1, 'http://highline.huffingtonpost.com/articles/en/the-21st-century-gold-rush-refugees/#/niger', 0, 'How the refugee crisis is changing the world economy.', 'society', 0, '2017-01-15 04:13:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1023, 1, 'http://highline.huffingtonpost.com/articles/en/the-21st-century-gold-rush-refugees/#/niger', 0, 'How the refugee crisis is changing the world economy.', 'society', 0, '2017-01-15 04:13:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1024, 1, 'https://www.technologyreview.com/s/603242/questionable-young-blood-transfusions-offered-in-us-as-anti-aging-remedy/?utm_campaign=add_this&utm_source=twitter&utm_medium=post', 0, 'Questionable â€œYoung Bloodâ€ Transfusions Offered in U.S. as Anti-Aging Remedy', 'scintech', 0, '2017-01-15 15:10:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1025, 1, 'http://hazlitt.net/murder-union-hill-road', 0, 'Murder on Union Hill Road', 'society', 0, '2017-01-15 15:33:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1026, 1, 'https://www.nytimes.com/2017/01/27/us/politics/trump-syrian-refugees.html', 0, 'Trump Bars Refugees and Citizens of 7 Muslim Countries', 'worldnhistory', 0, '2017-01-29 15:04:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1027, 1, 'http://www.cbc.ca/news/world/trump-putin-phone-call-1.3957830', 0, 'Putin, Trump discuss rebuilding U.S.-Russia ties', 'worldnhistory', 0, '2017-01-31 11:30:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1028, 1, 'http://www.blogto.com/fashion_style/2015/01/the_top_10_saunas_and_steam_rooms_in_toronto/', 0, 'The Top 10 Saunas and Steam Rooms In Toronto', 'society', 0, '2017-02-15 04:03:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1029, 1, 'https://broadly.vice.com/en_us/article/why-men-fall-in-love-faster-than-women', 0, 'Why Men Fall in Love Faster Than Women', 'sexndating', 0, '2017-02-16 12:00:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1030, 1, 'https://fractalenlightenment.com/35496/spirituality/5-sacred-herbs-for-cleansing-the-spirit', 0, '5 Sacred Herbs for Cleansing the Spirit', 'body', 0, '2017-02-17 04:22:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1031, 1, 'http://www.thisisinsider.com/drunk-foods-around-the-world-2016-8?utm_content=buffer45aa4&utm_medium=social&utm_source=facebook.com&utm_campaign=buffer/#turkey-ikembe-orbs-3', 0, 'The most popular drunk food in 21 cities around the world', 'worldnhistory', 0, '2017-02-21 11:52:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1032, 1, 'http://www.8asians.com/2013/10/23/reverse-racism-in-taiwan/', 0, 'Reverse Racism in Taiwan', 'society', 0, '2017-03-16 11:11:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1033, 1, 'https://fivethirtyeight.com/features/the-biggest-predictor-of-how-long-youll-be-unemployed-is-when-you-lose-your-job/', 0, 'The Biggest Predictor of How Long Youâ€™ll Be Unemployed Is When You Lose Your Job', 'society', 0, '2017-03-19 00:33:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1034, 1, 'https://www.theatlantic.com/education/archive/2017/03/measuring-college-unaffordability/520476/', 0, 'Measuring College (Un)affordability', 'society', 0, '2017-03-26 02:41:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1035, 1, 'https://undark.org/article/doctors-divide-on-pandas/?utm_content=buffer63fb4&utm_medium=social&utm_source=twitter.com&utm_campaign=buffer', 0, 'The mysterious affliction called PANDAS, in which childrenâ€™s behaviour changes after an illness.', 'society', 0, '2017-03-26 02:42:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1036, 1, 'https://techcrunch.com/2017/03/29/dominos-and-starship-technologies-will-deliver-pizza-by-robot-in-europe-this-summer/', 0, 'Dominoâ€™s and Starship Technologies will deliver pizza by robot in Europe this summer', 'scintech', 0, '2017-03-30 10:11:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1037, 1, 'https://ca.yahoo.com/news/human-waste-in-cans-forces-shutdown-at-coca-cola-plant-120122729.html', 0, 'â€˜Human wasteâ€™ in cans forces shutdown at Coca-Cola plant', 'society', 0, '2017-03-30 12:10:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1038, 1, 'http://www.edmontonsun.com/2014/03/18/federal-inmate-cost-soars-to-177gs-each-per-year', 0, 'Federal inmate cost soars to $117Gs each per year', 'society', 0, '2017-04-01 13:22:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1039, 1, 'http://www.cbc.ca/news/canada/toronto/hydro-one-ceo-s-4-5m-salary-won-t-be-reduced-to-help-cut-electricity-costs-1.4048675', 0, 'Hydro One CEO\'s $4.5M salary won\'t be reduced to help cut electricity costs', 'society', 0, '2017-04-01 13:23:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1040, 1, 'http://www.cbc.ca/news/canada/toronto/sunshine-list-2017-ontario-salaries-2016-1.4037987', 0, 'Annual list names all provincial, municipal and education workers earning $100K or more', 'society', 0, '2017-04-01 13:24:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1041, 1, 'http://www.ranker.com/list/celebrities-charged-with-domestic-abuse/celebrity-lists', 0, '80+ Celebrities Who Have Been Charged with Domestic Abuse', 'society', 0, '2017-04-02 11:19:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1042, 1, 'https://www.youtube.com/watch?v=K6geOms33Dk', 0, 'Can you make an airplane by using KFC buckets for wings?', 'scintech', 0, '2017-04-05 10:10:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1043, 1, 'https://www.youtube.com/watch?v=UOLLTVDf3O0', 0, '5 Comma Types That Can Make Or Break a Sentence', 'society', 0, '2017-04-09 11:17:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1044, 1, 'http://www.haneycodes.net/to-node-js-or-not-to-node-js/', 0, 'To Node.js Or Not To Node.js', 'scintech', 0, '2017-04-09 14:37:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1045, 1, 'https://www.youtube.com/watch?v=S4IHB3qK1KU', 0, 'Cat Freaks Out At Optical Illusion â€” Probably Thinks It\'s Food', 'general', 0, '2017-04-10 05:08:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1046, 1, 'http://www.cbc.ca/news/canada/nova-scotia/doctor-sarah-jones-pill-trafficking-trial-1.4064790', 0, 'Testimony begins at doctor\'s opioid trafficking trial', 'society', 0, '2017-04-11 13:43:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1047, 1, 'http://www.tmz.com/2017/04/12/charlie-murphy-dead-leukemia-eddie-murphy-brother/', 0, 'CHARLIE MURPHY DEAD AT 57 After Leukemia Battle', 'worldnhistory', 0, '2017-04-13 07:27:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1048, 1, 'http://www.narcity.com/toronto/12-secret-menu-items-in-toronto-restaurants-you-didnt-know-you-could-order/#', 0, '12 Secret Menu Items In Toronto Restaurants You Didnâ€™t Know You Could Order', 'society', 0, '2017-04-14 17:59:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1049, 1, 'http://www.popularmechanics.com/science/health/a26038/the-blood-of-the-crab/', 0, 'Horseshoe crab blood is an irreplaceable medical marvel', 'scintech', 0, '2017-04-15 11:54:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1050, 1, 'https://www.hanselman.com/blog/InstallingAndRunningNodejsApplicationsWithinIISOnWindowsAreYouMad.aspx', 0, 'Installing And Running Nodejs Applications Within IIS On Windows, Are You Mad?', 'scintech', 0, '2017-04-16 12:42:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1051, 1, 'http://nautil.us/blog/how-to-solve-oncologys-labor-crisis', 0, 'Oncology Labour Crisis', 'society', 0, '2017-04-23 18:11:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0);
INSERT INTO `articlelinks` (`linkid`, `linktype`, `link`, `imageid`, `title`, `category`, `articleid`, `createdate`, `revisedate`, `voteup`, `votedown`, `voteinternal`, `creatorid`, `numcomments`) VALUES
(1052, 1, 'https://www.bloomberg.com/news/features/2017-04-20/this-is-spinal-tap-s-400-million-lawsuit', 0, 'The $400 Million \'This Is Spinal Tap\' Lawsuit', 'society', 0, '2017-04-23 18:48:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1053, 1, 'https://www.ted.com/talks/curtis_wall_street_carroll_how_i_learned_to_read_and_trade_stocks_in_prison', 0, 'Curtis Wall Street Carroll: How I learned to read -- and trade stocks -- in prison', 'society', 0, '2017-04-29 16:04:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1054, 1, 'https://www.ted.com/talks/adam_foss_a_prosecutor_s_vision_for_a_better_justice_system', 0, 'Adam Foss: A prosecutor\'s vision for a better justice system', 'society', 0, '2017-04-29 16:06:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1055, 1, 'http://www.cbc.ca/news/business/equitable-bank-alternative-lender-1.4097010', 0, 'Alternative lender Equitable says all 6 big banks have agreed to fund $2B backstop', 'society', 0, '2017-05-04 01:37:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1056, 1, 'https://www.citylab.com/work/2017/05/where-automation-poses-the-biggest-threat-to-american-jobs/525240/', 0, 'Where Automation Poses the Biggest Threat to American Jobs', 'scintech', 0, '2017-05-06 11:50:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1057, 1, 'https://www.youtube.com/watch?v=UPZwnc_Lk2M', 0, 'We Tried To Steal Food From A Delivery Robot', 'scintech', 0, '2017-05-06 11:57:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1058, 1, 'https://dzone.com/articles/javas-observer-and-observable-are-deprecated-in-jd', 0, 'Java\'s Observer and Observable Are Deprecated in JDK 9', 'scintech', 0, '2017-05-11 10:27:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1059, 1, 'http://business.financialpost.com/fp-tech-desk/yo-ho-ho-and-a-bottle-of-rum-pirates-have-stolen-an-unreleased-disney-film-and-are-ransoming-it-ceo-says', 0, 'Pirates have stolen an unreleased Disney film and are ransoming it, CEO says', 'society', 0, '2017-05-16 14:31:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1060, 1, 'http://www.ctvnews.ca/health/researchers-create-prosthetic-ovaries-using-gelatin-and-a-3d-printer-1.3415835', 0, 'Researchers create prosthetic ovaries using gelatin and a 3D printer', 'scintech', 0, '2017-05-16 16:12:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1061, 1, 'http://www.seventeen.com/celebrity/news/a38503/some-sorority-members-are-upset-that-chris-rock-called-sororities-racist-at-the-oscars/', 0, 'Some Girls Are Upset That Chris Rock Called Sororities Racist at the Oscars', 'society', 0, '2017-05-17 07:11:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1062, 1, 'https://qz.com/984174/silicon-valley-has-idolized-steve-jobs-for-decades-and-its-finally-paying-the-price/', 0, 'Silicon Valley has idolized Steve Jobs for decadesâ€”and itâ€™s finally paying the price', 'society', 0, '2017-05-17 07:28:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1063, 1, 'http://digg.com/2017/hiv-international-security-mosaic', 0, 'How HIV Became A Matter Of International Security', 'worldnhistory', 0, '2017-05-17 08:22:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1064, 1, 'https://www.youtube.com/watch?v=6eniicMfa6g', 0, 'Turkish protesters body guards attacking protesters', 'worldnhistory', 0, '2017-05-17 09:01:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1065, 1, 'https://www.youtube.com/watch?v=cCBepOPe_6Y', 0, '10th May Massacre by Sri Lankan Army - 2', 'worldnhistory', 0, '2017-05-17 10:42:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1066, 1, 'http://www.newyorker.com/magazine/2017/05/22/an-underground-college-for-undocumented-immigrants?mbid=synd_digg', 0, 'AN UNDERGROUND COLLEGE FOR UNDOCUMENTED IMMIGRANTS', 'society', 0, '2017-05-17 13:18:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1067, 1, 'https://www.fastcompany.com/40420451/companies-steal-15-billion-from-their-employees-every-year?utm_content=buffer2c2fd&utm_medium=social&utm_source=twitter.com&utm_campaign=buffer', 0, 'Companies Steal $15 Billion From Their Employees Every Year', 'society', 0, '2017-05-17 13:46:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1068, 1, 'https://www.thrillist.com/entertainment/nation/oscar-winning-movies-box-office-hits-birthday-years', 0, 'THE BIGGEST MOVIE FROM THE YEAR YOU WERE BORN', 'worldnhistory', 0, '2017-05-19 09:16:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1069, 1, 'https://www.theglobeandmail.com/news/national/health-minister-orders-opioid-review-after-conflict-of-interest-revelations/article35053108/', 0, 'Health Minister orders review of opioid guidelines after conflict-of-interest revelations', 'society', 0, '2017-05-19 14:31:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1070, 1, 'http://www.zmescience.com/science/radio-shield-van-allen-belts/', 0, 'Weâ€™ve (unknowingly) created a radiation shield around the Earth using radios', 'society', 0, '2017-05-19 14:42:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1071, 1, 'https://www.nytimes.com/interactive/2017/05/26/business/100000005117223.mobile.html?_r=0', 0, 'The Highest-Paid C.E.O.s in 2016', 'society', 0, '2017-05-27 20:30:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1072, 1, 'https://www.vice.com/en_us/article/the-revolution-wont-start-until-we-talk-about-our-salaries?utm_source=vicetwitterus', 0, 'The Revolution Won\'t Start Until We Talk About Our Salaries', 'society', 0, '2017-05-27 23:47:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1073, 1, 'http://danwang.co/why-so-few-computer-science-majors/', 0, 'Why do so few people major in computer science?', 'scintech', 0, '2017-05-30 08:11:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1074, 1, 'https://qz.com/991030/your-single-coworkers-and-employees-arent-there-to-pick-up-the-slack-for-married-people/', 0, 'Single workers arenâ€™t there to pick up the slack for their married bosses and colleagues', 'sexndating', 0, '2017-05-30 08:24:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1075, 1, 'http://nymag.com/scienceofus/2017/05/genetics-intelligence.html', 0, 'Yes, There Is a Genetic Component to Intelligence', 'scintech', 0, '2017-05-30 12:33:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1076, 1, 'http://money.cnn.com/2017/05/28/technology/chipotle-credit-card-hack/index.html?sr=twCNN052917chipotle-credit-card-hack0538AMVODtopLink&linkId=38106786', 0, 'Most Chipotle restaurants hacked with credit card stealing malware', 'scintech', 0, '2017-05-30 12:34:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1077, 1, 'https://qz.com/993258/dirt-has-a-microbiome-and-it-may-double-as-an-antidepressant/', 0, 'Dirt has a microbiome, and it may double as an antidepressant', 'scintech', 0, '2017-05-30 16:26:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1078, 1, 'https://www.wired.com/2017/05/cutting-h-1b-visas-endangers-scientific-progress-everyone/?mbid=synd_digg', 0, 'Cutting H-1B Visas Endangers Scientific Progress For Everyone', 'worldnhistory', 0, '2017-05-31 10:18:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1079, 1, 'https://www.citylab.com/life/2017/05/do-jobs-follow-people-or-do-people-follow-jobs/523296/', 0, 'Do Jobs Follow People or Do People Follow Jobs?', 'society', 0, '2017-05-31 10:20:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1080, 1, 'https://krebsonsecurity.com/2017/06/onelogin-breach-exposed-ability-to-decrypt-data/', 0, 'OneLogin: Breach Exposed Ability to Decrypt Data', 'scintech', 0, '2017-06-01 20:19:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1081, 1, 'https://www.buzzfeed.com/ellievhall/manila-resorts-world?utm_term=.anMMwj9gK#.bcLk9BWLE', 0, '35 People Were Found Dead Inside A Manila Resort Targeted In An Apparent Robbery', 'worldnhistory', 0, '2017-06-02 19:34:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1082, 1, 'https://qz.com/994719/how-to-rob-a-bank-according-to-economists-who-analyzed-bank-heists-in-italy/', 0, 'How to rob a bank, according to economics', 'society', 0, '2017-06-03 01:03:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1083, 1, 'https://theoutline.com/post/1606/sputnik-monroe-pro-wrestler-memphis-integration', 0, 'Sputnik Monroe understood the purchasing power of black people and transformed Memphisâ€™ pro wrestling fanbas', 'worldnhistory', 0, '2017-06-03 01:07:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1084, 1, 'https://www.youtube.com/watch?v=QQmqMZ-1v7c', 0, 'How To Argue With Your Partner', 'sexndating', 0, '2017-06-03 11:37:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1085, 1, 'http://elitedaily.com/life/unable-forgive-makes-smart-not-weak/943638/', 0, 'Why Being Unable To Forgive Makes You Smart, Not Weak', 'society', 0, '2017-06-03 22:13:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1086, 1, 'http://io9.gizmodo.com/heres-what-your-brain-is-doing-when-you-really-really-1656710293', 0, 'Here\'s What Your Brain Is Doing When You Really, Really Hate Someone', 'body', 0, '2017-06-03 22:13:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1087, 1, 'https://www.buzzfeed.com/matthewzeitlin/inequality-could-be-even-worse-than-we-think?utm_term=.vtmkJPZnA#.xyM9pwl1o', 0, 'The Gap Between Rich And Poor Could Be Even Wider Than We Think', 'worldnhistory', 0, '2017-06-04 06:10:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1088, 1, 'http://www.cbc.ca/news/world/london-bridge-police-respond-incident-1.4145353', 0, '\'Twisted and cowardly terrorists\' condemned after London attackers kill 7, injure 48', 'worldnhistory', 0, '2017-06-04 11:34:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1089, 1, 'https://www.inverse.com/article/32370-how-to-have-casual-sex-summer-fling-okcupid', 0, 'OKCupid Data Proves June Is Prime Casual Sex Season', 'sexndating', 0, '2017-06-04 12:16:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1090, 1, 'https://www.buzzfeed.com/lauraturner/christian-health-care?utm_term=.mo2Q8vwxB#.tte3kM6Lr', 0, 'How Over A Million Christians Have Opted Out Of Health Insurance', 'society', 0, '2017-06-04 12:30:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1091, 1, 'https://www.theatlantic.com/health/archive/2017/06/nejm-letter-opioids/528840/', 0, 'The One-Paragraph Letter From 1980 That Fueled the Opioid Crisis', 'worldnhistory', 0, '2017-06-04 12:32:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1092, 1, 'http://www.dailykos.com/story/2013/1/25/1182220/-Research-Study-Explains-How-U-S-Media-Brainwashes-The-Public', 0, 'Research Study Explains How U.S. Media Brainwashes The Public', 'society', 0, '2017-06-04 13:02:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1093, 1, 'https://youtu.be/qbxB_ebWPf0', 0, 'Girl Dating To Get Free Meals, Saves 1200$ a Month', 'sexndating', 0, '2017-06-04 13:15:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1094, 1, 'http://www.businessinsider.com/confessions-how-she-made-1200-a-month-using-matchcom-2011-11', 0, 'This Young Woman Scored $1,200 A Month In Fancy Dinners Using Match.com', 'sexndating', 0, '2017-06-04 13:18:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1095, 1, 'https://www.washingtonpost.com/lifestyle/magazine/why-are-african-americans-so-much-more-likely-than-whites-to-develop-alzheimers/2017/05/31/9bfbcccc-3132-11e7-8674-437ddb6e813e_story.html?utm_term=.dd940745d9dd', 0, 'African Americans are more likely than whites to develop Alzheimerâ€™s. Why?', 'scintech', 0, '2017-06-04 13:31:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1096, 1, 'https://www.canindia.com/bengal-medical-council-pleads-helplessness-on-fake-doctors/', 0, 'Bengal medical council pleads helplessness on fake doctors', 'worldnhistory', 0, '2017-06-06 12:45:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1097, 1, 'https://www.bloomberg.com/news/articles/2013-04-04/why-your-student-loan-interest-rate-is-so-high', 0, 'Why Are Your Student Loan Interest Rates So High?', 'society', 0, '2017-06-06 13:07:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1098, 1, 'http://www.cnn.com/2017/06/06/health/drinking-brain-changes-study/', 0, 'Moderate drinking may alter brain, study says', 'body', 0, '2017-06-07 11:29:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1099, 1, 'https://www.theglobeandmail.com/news/national/strokes-on-the-rise-among-young-canadians-report-says/article35228147/', 0, 'Strokes on the rise among young Canadians, report says', 'body', 0, '2017-06-07 11:29:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1100, 1, 'http://www.ctvnews.ca/business/uber-dismisses-over-20-employees-after-law-firm-s-probe-1.3447034', 0, 'Uber dismisses over 20 employees after law firm\'s probe', 'society', 0, '2017-06-07 11:29:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1101, 1, 'http://ottawacitizen.com/news/local-news/ontario-looks-at-ways-to-make-child-care-more-affordable', 0, 'Ontario looks at ways to make child care more affordable', 'society', 0, '2017-06-07 11:38:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1102, 1, 'http://news.nationalpost.com/news/canada/canadian-politics/witches-and-duellers-rejoice-probably-as-the-government-scraps-outdated-laws', 0, 'Witches and duellers rejoice (probably) as the government scraps outdated laws', 'worldnhistory', 0, '2017-06-07 11:39:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1103, 1, 'https://www.bloomberg.com/news/features/2017-06-07/fiduciary-rule-fight-brews-while-bad-financial-advisers-multiply', 0, 'Why You Still Canâ€™t Trust Your Financial Adviser', 'society', 0, '2017-06-08 00:02:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1104, 1, 'https://www.recode.net/2017/6/7/15754316/uber-executive-india-assault-rape-medical-records', 0, 'A top Uber executive, who obtained the medical records of a customer who was a rape victim, has been fired', 'society', 0, '2017-06-08 00:15:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1105, 1, 'https://www.racked.com/2017/6/7/15740564/luxury-weddings', 0, 'Weddings of the 0.01 Percent', 'sexndating', 0, '2017-06-08 01:10:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1106, 1, 'https://www.theatlantic.com/science/archive/2017/06/sourdough-versus-white-bread/529260/', 0, 'Scientists Pit Sourdough Against White Breadâ€”With Surprising Results', 'body', 0, '2017-06-08 09:44:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1107, 1, 'https://motherboard.vice.com/en_us/article/the-case-for-letting-robots-make-our-clothes', 0, 'The Case for Letting Robots Make Our Clothes', 'scintech', 0, '2017-06-08 12:23:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1108, 1, 'https://www.nytimes.com/2017/06/07/world/asia/myanmar-military-plane.html?_r=0', 0, 'Wreckage of Missing Myanmar Military Plane Is Found', 'worldnhistory', 0, '2017-06-08 12:48:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1109, 1, 'https://www.vice.com/en_us/article/i-fooled-wall-street-and-the-mafia-as-an-undercover-fbi-agent', 0, 'I Fooled Wall Street and the Mafia as an Undercover FBI Agent', 'society', 0, '2017-06-08 12:48:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1110, 1, 'https://www.bloomberg.com/news/features/2017-06-08/no-one-has-ever-made-a-corruption-machine-like-this-one', 0, 'No One Has Ever Made a Corruption Machine Like This One', 'society', 0, '2017-06-08 23:43:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1111, 1, 'https://www.fastcompany.com/1841912/true-costs-launching-startup', 0, 'The True Cost Of Launching A Startup', 'society', 0, '2017-06-09 13:09:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1112, 1, 'http://www.cnbc.com/2017/06/09/big-five-tech-stocks-sell-off-facebook-apple-amazon-microsoft-alphabet.html', 0, 'The five biggest tech stocks lost nearly $100 billion in value on Friday', 'scintech', 0, '2017-06-11 14:06:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1113, 1, 'https://www.theregister.co.uk/2017/06/05/dev_accidentally_nuked_production_database_was_allegedly_instantly_fired/', 0, 'First-day-on-the-job dev: I accidentally nuked production database, was instantly fired', 'scintech', 0, '2017-06-11 14:24:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1114, 1, 'https://www.engadget.com/2017/06/11/malware-downloader-infects-your-pc-without-a-mouse-click/', 0, 'Malware downloader infects your PC without a mouse click', 'scintech', 0, '2017-06-11 22:46:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1115, 1, 'https://www.bleepingcomputer.com/news/security/ex-admin-deletes-all-customer-data-and-wipes-servers-of-dutch-hosting-provider/', 0, 'Ex-Admin Deletes All Customer Data and Wipes Servers of Dutch Hosting Provider', 'society', 0, '2017-06-11 22:48:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1116, 1, 'http://www.bbc.com/news/world-us-canada-39813825', 0, 'Obamacare is \'dead\' says Trump after healthcare victory', 'society', 0, '2017-06-12 04:20:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1117, 1, 'https://www.nytimes.com/2017/06/10/us/politics/trump-comey-russia-fbi.html?_r=1', 0, 'Former FBI Director Predicts Russian Hackers Will Interfere With More Elections', 'society', 0, '2017-06-12 05:04:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1118, 1, 'http://www.dailymail.co.uk/sciencetech/article-4602816/Astronomers-discover-two-new-MOONS-orbiting-Jupiter.html', 0, 'Jupiter now has 69 moons: Astronomers discover two new satellites orbiting the gas giant', 'scintech', 0, '2017-06-14 12:41:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1119, 1, 'https://www.theatlantic.com/health/archive/2017/06/kybella-the-injection-that-melts-a-double-chin/529893/?utm_source=atltw', 0, 'The Injection That Melts a Double Chin', 'body', 0, '2017-06-15 00:13:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1120, 1, 'http://digg.com/2017/congressional-shooting-baseball-game', 0, 'House Majority Whip And A Former Congressional Staffer Are In Critical Condition After Shooting', 'worldnhistory', 0, '2017-06-15 00:32:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1121, 1, 'https://phys.org/news/2017-06-evidence-stars-born-pairs.html', 0, 'New evidence that all stars are born in pairs', 'scintech', 0, '2017-06-15 01:24:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1122, 1, 'http://www.chch.com/major-gang-bust/', 0, 'Major gang bust', 'society', 0, '2017-06-17 12:56:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1123, 1, 'http://www.timescolonist.com/milk-recall-mounties-investigate-after-harmful-material-found-in-milk-1.20636996', 0, 'Milk recall: Mounties investigate after â€˜harmfulâ€™ material found in milk', 'society', 0, '2017-06-17 13:50:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1124, 1, 'http://www.bnn.ca/osc-permanently-bans-drabinsky-from-directing-publicly-traded-companies-1.781314', 0, 'OSC bans Garth Drabinsky from becoming director or officer of public company', 'society', 0, '2017-06-17 13:51:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1125, 1, 'http://www.techtimes.com/articles/210195/20170617/facebook-moderators-at-risk-after-security-flaw-exposes-their-identities-to-suspected-terrorists.htm', 0, 'Facebook Moderators At Risk After Security Flaw Exposes Their Identities To Suspected Terrorists', 'society', 0, '2017-06-17 13:52:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1126, 1, 'http://www.reuters.com/article/usa-cuba-idUSL1N1JD05E', 0, 'RPT-Trump to clamp down on Cuba travel, trade, curbing Obama\'s detente', 'worldnhistory', 0, '2017-06-17 13:54:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1127, 1, 'http://www.news.com.au/technology/science/space/the-sun-had-an-evil-twin-called-nemesis-which-may-have-wiped-out-the-dinosaurs-claim-astronomers/news-story/af0ecea68ca66d11d3a495d2749daa79', 0, 'The sun had an â€˜evil twinâ€™ called Nemesis which may have wiped out the dinosaurs, claim astronomers', 'scintech', 0, '2017-06-17 13:56:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1128, 1, 'http://globalnews.ca/news/3536100/more-victims-sexual-assault-north-york/', 0, 'More victims come forward of sexual assault suspect who offered â€˜blessingsâ€™', 'society', 0, '2017-06-17 15:58:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1129, 1, 'https://www.thestar.com/life/health_wellness/2017/06/19/ontario-doctors-go-to-court-to-keep-billing-information-secret.html', 0, 'Ontario doctors go to court to keep billing information secret', 'society', 0, '2017-06-19 15:06:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1130, 1, 'https://www.theatlantic.com/theplatinumpatients', 0, 'Five Percent Of Americans Account For 50 Percent Of US Medical Bills', 'body', 0, '2017-06-19 16:14:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1131, 1, 'http://digg.com/2017/registered-voter-data-breach', 0, 'If You\'re A Registered Voter, Your Personal Data Was Likely Exposed By A Data Firm', 'scintech', 0, '2017-06-19 16:56:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1132, 1, 'https://blog.acolyer.org/2017/06/23/cloak-and-dagger-from-two-permissions-to-complete-control-of-the-ui-feedback-loop/?lipi=urn%3Ali%3Apage%3Ad_flagship3_feed%3BuUhag%2Bp3SLe7MbG5p5RH%2FA%3D%3D', 0, 'Cloak and dagger: from two permissions to complete control of the UI feedback loop', 'scintech', 0, '2017-06-25 05:27:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1133, 1, 'https://broadly.vice.com/en_us/article/43y99g/men-legally-allowed-to-finish-sex-even-if-woman-revokes-consent-nc-law-states', 0, 'Men Legally Allowed to Finish Sex Even If Woman Revokes Consent, NC Law States', 'society', 0, '2017-06-26 05:42:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1134, 1, 'https://www.darknet.org.uk/2006/12/writing-worms-for-fun-or-profit/', 0, 'Writing Worms for Fun or Profit', 'scintech', 0, '2017-06-27 06:20:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1135, 1, 'http://www.hackingpages.com/2016/08/how-to-create-your-own-worm-virus.html', 0, 'Worm Coding', 'scintech', 0, '2017-06-27 06:21:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1136, 1, 'https://timeline.com/the-kkk-started-a-branch-just-for-women-in-the-1920s-and-half-a-million-joined-72ab1439b78b', 0, 'The KKK started a branch just for women in the 1920s, and half a million joined', 'worldnhistory', 0, '2017-07-02 00:58:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1137, 1, 'https://www.quora.com/Why-are-mattresses-so-expensive', 0, 'Why are mattresses so expensive?', 'society', 0, '2017-07-02 04:54:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1138, 1, 'http://www.msn.com/en-ca/news/world/disgraced-doctor-threatened-former-colleagues-before-rampage/ar-BBDvB6J?li=AAggFp5&ocid=iehp', 0, 'Disgraced doctor threatened former colleagues before rampage ', 'society', 0, '2017-07-02 14:23:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1139, 1, 'http://www.ibtimes.com/political-capital/justice-departments-corporate-crime-watchdog-resigns-saying-trump-makes-it', 0, 'Justice Department\'s Corporate Crime Watchdog Resigns, Saying Trump Makes It Impossible To Do Job', 'society', 0, '2017-07-03 15:01:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1140, 1, 'https://www.thespec.com/news-story/7403734-microsoft-set-to-announce-thousands-of-layoffs-as-it-focuses-on-cloud-software/', 0, 'Microsoft set to announce thousands of layoffs as it focuses on cloud software', 'scintech', 0, '2017-07-03 17:30:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1141, 1, 'https://techcrunch.com/2017/07/03/uk-data-regulator-says-deepminds-initial-deal-with-the-nhs-broke-privacy-law/', 0, 'UK data regulator says DeepMindâ€™s initial deal with the NHS broke privacy law', 'society', 0, '2017-07-03 17:35:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1142, 1, 'https://www.theglobeandmail.com/opinion/sri-lankas-atrocity-against-the-tamils-is-no-longer-in-doubt/article9013462/', 0, 'Sri Lankaâ€™s atrocity against the Tamils is no longer in doubt', 'worldnhistory', 0, '2017-07-04 06:36:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1143, 1, 'https://www.bloomberg.com/news/articles/2017-07-13/why-white-collar-criminals-often-go-free-chickenshit-club-review?cmpid=socialflow-twitter-businessweek&utm_content=businessweek&utm_campaign=socialflow-organic&utm_source=twitter&utm_medium=social', 0, 'Here\'s Why White-Collar Criminals Often Go Free', 'society', 0, '2017-07-16 00:36:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1144, 1, 'https://kretzerfirm.com/ceos-need-criminal-defense-lawyer/', 0, 'Why CEOs Need a Criminal Defense Lawyer', 'society', 0, '2017-07-16 00:38:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1145, 1, 'https://qz.com/1033354/we-still-have-no-idea-why-humans-speak-over-7000-languages/', 0, 'We still have no idea why humans speak over 7,000 languages', 'worldnhistory', 0, '2017-07-22 17:26:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1146, 1, 'https://www.javacodegeeks.com/2015/07/dont-blame-bad-software-on-developers-blame-it-on-their-managers.html', 0, 'Donâ€™t Blame Bad Software on Developers â€“ Blame it on their Managers', 'scintech', 0, '2017-07-23 14:33:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1147, 1, 'https://undark.org/article/mystery-diseases-syndromes-health-care/', 0, 'The Curse of a â€˜None of the Aboveâ€™ Disease', 'scintech', 0, '2017-07-26 07:50:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1148, 1, 'http://www.vulture.com/2017/07/t-j-miller-on-leaving-hbo-silicon-valley.html', 0, 'People Need a Villain', 'society', 0, '2017-07-26 09:42:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1149, 1, 'https://www.youtube.com/watch?time_continue=19&v=CeDOQpfaUc8', 0, 'Adam Ruins Everything - The Real Reason Hospitals Are So Expensive', 'society', 0, '2017-07-28 01:42:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1150, 1, 'https://www.nytimes.com/2017/07/28/world/europe/us-russia-sanctions.html', 0, 'Russia Seizes 2 U.S. Properties and Orders Embassy to Cut Staff', 'worldnhistory', 0, '2017-07-28 12:44:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1151, 1, 'http://www.blogto.com/eat_drink/2016/04/the_top_5_deep_dish_pizza_in_toronto/', 0, 'The Top 5 Deep Dish Pizzas In Toronto', 'society', 0, '2017-07-29 22:15:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1152, 1, 'https://www.theglobeandmail.com/news/politics/canada-aids-in-thai-arrest-of-tamil-migrants/article4190512/', 0, 'Canada aids in Thai arrest of Tamil migrants', 'society', 0, '2017-07-30 14:36:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1153, 1, 'https://www.thestar.com/news/gta/2017/06/19/retrieved-lifeboat-tells-stories-of-tamil-refugees.html', 0, 'Retrieved lifeboat tells stories of Tamil refugees', 'society', 0, '2017-07-30 14:37:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1154, 1, 'http://www.torontosun.com/news/canada/2011/02/08/17197306.html', 0, 'Tamil boat costs taxpayers at least $25 million', 'society', 0, '2017-07-30 14:38:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1155, 1, 'https://www.thestar.com/news/canada/2008/06/17/canada_brands_tamil_group_as_terrorist_front_for_tigers.html', 0, 'Canada brands Tamil group as terrorist front for Tigers', 'worldnhistory', 0, '2017-07-30 17:55:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1156, 1, 'http://timesofindia.indiatimes.com/india/India-behind-Lankas-victory-over-LTTE-Book/articleshow/4924585.cms', 0, 'India behind Lanka\'s victory over LTTE: Book', 'worldnhistory', 0, '2017-07-30 17:56:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1157, 1, 'https://youtu.be/R4WX3sMzZNo', 0, 'French Woman Sets Hair On Fire', 'society', 0, '2017-07-31 04:04:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1158, 1, 'http://nautil.us/blog/-a-new-explanation-for-one-of-the-strangest-occurrences-in-natureball-lightning', 0, 'A New Explanation for One of the Strangest Occurrences in Natureâ€”Ball Lightning', 'scintech', 0, '2017-08-02 01:29:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1159, 1, 'http://www.ctvnews.ca/world/saudi-arabia-says-there-s-no-proof-it-backed-9-11-attack-1.3528457', 0, 'Saudi Arabia says there\'s no proof it backed 9-11 attack', 'worldnhistory', 0, '2017-08-02 01:32:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1160, 1, 'https://www.washingtonpost.com/world/national-security/justice-department-plans-new-project-to-sue-universities-over-affirmative-action-policies/2017/08/01/6295eba4-772b-11e7-8f39-eeb7d3a2d304_story.html?utm_term=.3a80d1076887', 0, 'Justice Department plans new project to sue universities over affirmative action policies', 'worldnhistory', 0, '2017-08-02 11:45:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1161, 1, 'http://digg.com/2017/5-unique-projects-you-can-build-with-arduino', 0, '5 Unique Projects You Can Build With Arduino', 'scintech', 0, '2017-10-06 12:45:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1162, 1, 'https://www.theatlantic.com/politics/archive/2017/10/necessity-of-questioning-military/543576/', 0, 'The Necessity of Questioning the Military', 'worldnhistory', 0, '2017-10-24 12:21:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1163, 1, 'https://www.msn.com/en-ca/money/topstories/12-things-recruiters-say-drive-them-crazy-in-job-interviews/ss-AAsCZrd?ocid=spartandhp#image=1', 0, '12 things recruiters say drive them crazy in job interviews', 'society', 0, '2017-10-24 14:26:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1164, 1, 'https://www.cnbc.com/2017/10/27/tech-stocks-leaping-higher-after-blowout-earnings-from-amazon-alphabet-and-microsoft.html', 0, 'Nasdaq, S&P 500 leap to record highs after blowout tech earnings', 'scintech', 0, '2017-10-27 16:30:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1165, 1, 'http://www.rollingstone.com/politics/features/taibbi-the-great-college-loan-swindle-w510880', 0, 'The Great College Loan Swindle', 'general', 0, '2017-11-05 23:37:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1166, 1, 'https://www.fastcompany.com/40485634/equifax-salary-data-and-the-work-number-database', 0, 'This Time, Facebook Is Sharing Its Employeesâ€™ Data', 'society', 0, '2017-11-10 02:45:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1167, 1, 'https://www.youtube.com/watch?v=FZ_jNGKCIWs', 0, 'Why do you need to get a flu shot every year?', 'scintech', 0, '2017-11-25 12:51:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1168, 1, 'https://www.statnews.com/2017/11/27/scarlet-fever-cases/', 0, 'Scarlet fever, a disease of yore, is making a comeback in parts of the world', 'worldnhistory', 0, '2017-11-28 02:19:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1169, 1, 'https://medium.com/@NetflixTechBlog', 0, 'Netflix Technology Blog', 'scintech', 0, '2017-11-28 03:34:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1170, 1, 'https://ask.slashdot.org/story/14/06/15/1626209/ask-slashdot-best-rapid-development-language-to-learn-today', 0, 'Best Rapid Development Language To Learn Today?', 'scintech', 0, '2017-11-29 05:33:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1171, 1, 'http://digg.com/2017/why-health-care-is-so-expensive', 0, 'This Is Why Health Care Costs So Much', 'body', 0, '2017-11-29 17:03:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1172, 1, 'https://www.youtube.com/watch?time_continue=15&v=usbyJLOiFbE', 0, 'This Clever Flat-Pack House Can Be Assembled In Six Hours', 'scintech', 0, '2017-11-29 17:07:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1173, 1, 'http://www.cbc.ca/news/health/capsule-for-fecal-transplant-as-good-as-colonoscopy-to-treat-c-difficile-1.4424444', 0, '\'Poop pills\' as good as colonoscopy to treat C. difficile: study', 'scintech', 0, '2017-11-29 17:15:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1174, 1, 'https://www.thestar.com/news/gta/2015/05/17/ontario-allowing-employers-to-fire-workers-without-cause.html', 0, 'Ontario allowing employers to fire workers without cause', 'society', 0, '2017-11-29 18:35:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1175, 1, 'https://www.npr.org/sections/ed/2017/11/28/564054556/what-really-happened-at-the-school-where-every-senior-got-into-college', 0, 'What Really Happened At The School Where Every Graduate Got Into College', 'worldnhistory', 0, '2017-11-29 21:10:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1176, 1, 'https://www.bustle.com/articles/150162-7-signs-you-cant-trust-a-friend-what-to-do-about-it', 0, '7 Signs You Can\'t Trust A Friend & What To Do About It', 'society', 0, '2017-11-30 14:05:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1177, 1, 'http://www.thisisinsider.com/anna-victoria-photos-before-after-cheat-meal-2017-8?utm_content=bufferefd6d&utm_medium=social&utm_source=facebook.com&utm_campaign=buffer-fitness', 0, 'Fitness blogger Anna Victoria reveals what happens to her body after eating a cheat meal', 'body', 0, '2017-12-01 03:52:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1178, 1, 'https://stackoverflow.com/questions/21343846/change-the-database-in-which-asp-net-identity-stores-user-data', 0, 'Change the database in which ASP.NET Identity stores user data', 'scintech', 0, '2017-12-01 04:47:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1179, 1, 'https://www.vox.com/policy-and-politics/2017/12/1/16686014/phillip-parhamovich-civil-forfeiture', 0, 'â€œItâ€™s been complete hellâ€: how police used a traffic stop to take $91,800 from an innocent man', 'society', 0, '2017-12-03 13:48:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1180, 1, 'https://www.insidermonkey.com/blog/the-9-largest-private-armies-in-the-world-what-are-they-fighting-for-179460/', 0, 'A Look At The World\'s Most Powerful Mercenary Armies', 'worldnhistory', 0, '2017-12-04 15:27:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1181, 1, 'https://ca.yahoo.com/finance/news/stingy-canadian-employers-face-workforce-160600449.html', 0, 'Stingy Canadian Employers Face â€˜Workforce Crisisâ€™ In 2018: Report', 'worldnhistory', 0, '2017-12-04 15:30:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1182, 1, 'http://beta.latimes.com/local/lanow/la-me-ln-rupert-tarsey-20171129-htmlstory.html', 0, 'As a teen, he savagely beat a classmate. The attack was forgotten, until he went into politics', 'society', 0, '2017-12-06 18:46:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1183, 1, 'http://www.cbc.ca/news/business/ge-power-layoffs-1.4437645', 0, 'GE to shed 12,000 jobs worldwide as demand for traditional power plants drops', 'worldnhistory', 0, '2017-12-08 07:14:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1184, 1, 'http://www.cbc.ca/news/canada/british-columbia/found-foot-1.4438912', 0, 'Human foot found on southern Vancouver Island', 'society', 0, '2017-12-08 07:16:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1185, 1, 'http://toronto.citynews.ca/2017/12/07/specialist-wait-times-canada-ontarians-wait-shortest/', 0, 'Specialist wait times up in Canada, Ontarians wait the shortest', 'society', 0, '2017-12-08 07:18:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1186, 1, 'https://globalnews.ca/news/3903960/calgary-reports-3-more-flu-deaths-as-2017-cases-continue-to-climb/', 0, 'Calgary reports 3 more flu deaths as 2017 cases continue to climb', 'worldnhistory', 0, '2017-12-08 07:18:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1187, 1, 'http://www.cbc.ca/news/entertainment/jk-rowling-depp-defend-1.4437424', 0, 'J.K. Rowling, Warner Bros. defend casting Johnny Depp in Fantastic Beasts', 'society', 0, '2017-12-08 07:20:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1188, 1, 'http://www.cbc.ca/news/business/softwood-lumber-1.4437524', 0, 'U.S. trade body rules Canadian softwood hurts U.S. industry', 'society', 0, '2017-12-08 07:21:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1189, 1, 'http://www.cbc.ca/news/business/cannimed-pharma-choice-1.4437352', 0, 'CanniMed to supply pot products to PharmaChoice', 'society', 0, '2017-12-08 07:22:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1190, 1, 'http://www.cbc.ca/news/world/trump-jerusalem-us-1.4436999', 0, 'Palestinian president calls Trump\'s Jerusalem declaration \'unacceptable crime\'', 'worldnhistory', 0, '2017-12-08 07:23:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1191, 1, 'https://globalnews.ca/news/3902568/suspect-canada-line-racist-attack-court/', 0, 'Suspect in Canada Line racist attack to appear in court', 'society', 0, '2017-12-08 07:29:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1192, 1, 'https://www.ctvnews.ca/world/two-australians-jailed-in-brutal-slaying-of-aboriginal-woman-1.3712606', 0, 'Two Australians jailed in brutal slaying of Aboriginal woman', 'worldnhistory', 0, '2017-12-08 07:30:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1193, 1, 'http://www.cbc.ca/news/world/california-wildfires-1.4437148', 0, 'Southern California warns residents be \'ready to GO!\' as fires rage', 'worldnhistory', 0, '2017-12-08 07:34:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1194, 1, 'http://www.ctvnews.ca/world/same-sex-marriage-becomes-law-in-australia-weddings-to-start-in-january-1.3712665', 0, 'Same-sex marriage becomes law in Australia, weddings to start in January', 'worldnhistory', 0, '2017-12-08 08:33:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1195, 1, 'http://digg.com/2017/bitcoin-value-what-the-heck', 0, 'What You Should Know About Bitcoin\'s Ridiculous Surge In Value', 'scintech', 0, '2017-12-08 08:45:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1196, 1, 'https://qz.com/1149260/rich-countries-are-reducing-their-emissions-by-exporting-them-to-china/', 0, 'Rich countries are reducing their emissionsâ€”by exporting them to China', 'worldnhistory', 0, '2017-12-08 08:52:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1197, 1, 'https://splinternews.com/what-we-can-all-learn-from-domestic-workers-silent-batt-1820972737', 0, 'What We Can All Learn From Domestic Workers\' Silent Battle Against Sexual Harassment', 'society', 0, '2017-12-08 13:04:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1198, 1, 'https://www.coindesk.com/bank-of-america-outlines-cryptocurrency-exchange-system-in-patent-award/', 0, 'Bank of America Wins Patent for Crypto Exchange System', 'scintech', 0, '2017-12-08 13:57:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1199, 1, 'https://www.npr.org/sections/thetwo-way/2017/12/08/569331491/x-men-director-bryan-singer-accused-of-sexual-assault', 0, '\'X-Men\' Director Bryan Singer Accused Of Sexual Assault', 'society', 0, '2017-12-08 16:56:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1200, 1, 'https://www.thesun.co.uk/money/5078469/iota-price-how-to-buy-cryptocurrency-bitcoin/', 0, 'A BIT LIKE BITCOIN Iota price and how to buy â€“ what is the cryptocurrency and is it as valuable as Bitcoin?', 'scintech', 0, '2017-12-08 17:03:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1201, 2, NULL, 0, 'When is a door not a door?', 'general', 23, '2017-12-08 17:18:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 2),
(1202, 1, 'http://www.businessinsider.com/bi-mercenary-armies-2012-2#', 0, 'A Look At The World\'s Most Powerful Mercenary Armies', 'society', 0, '2017-12-08 18:53:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1203, 1, 'https://ca.style.yahoo.com/flu-kill-healthy-20-year-old-just-two-days-170356904.html', 0, 'How could the flu kill a healthy 20-year-old in just two days?', 'body', 0, '2017-12-08 20:22:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1204, 1, 'https://splinternews.com/how-did-a-white-supremacist-get-a-job-as-an-equal-emplo-1821061611', 0, 'How Did a White Supremacist Get a Job as an Equal Employment Officer?', 'worldnhistory', 0, '2017-12-09 02:32:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1205, 1, 'http://digg.com/video/boy-steals-alcohol', 0, 'Teenager Tries To Steal Booze, Despite Everyone In The Supermarket Watching Him', 'society', 0, '2017-12-10 02:27:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1206, 1, 'https://theintercept.com/2017/12/08/barack-obama-housing-policy-racial-inequality/', 0, 'NEW REPORT LOOKS AT HOW OBAMAâ€™S HOUSING POLICIES DESTROYED BLACK WEALTH', 'society', 0, '2017-12-11 06:42:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1207, 1, 'https://dzone.com/articles/why-tech-leads-are-not-the-way-to-go', 0, 'Why Tech Leads Are Not the Way to Go', 'scintech', 0, '2017-12-19 01:14:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1208, 1, 'https://news.nationalgeographic.com/2017/01/human-pig-hybrid-embryo-chimera-organs-health-science/', 0, 'Human-Pig Hybrid Created in the Lab â€” Here Are the Facts', 'scintech', 0, '2017-12-20 15:31:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1209, 1, 'https://www.geekwire.com/2017/washington-ag-expands-100m-lawsuit-comcast-extent-deception-shocking/', 0, 'Washington AG expands $100M lawsuit against Comcast: â€˜The extent of their deception is shockingâ€™', 'society', 0, '2017-12-23 06:16:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1210, 1, 'http://www.cbc.ca/news/canada/saskatoon/via-rail-stranded-spy-hill-1.4464542', 0, 'Via Rail train\'s mechanical failure strands 98 passengers in Spy Hill, Sask.', 'society', 0, '2017-12-26 03:48:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1211, 1, 'https://www.roberthalf.ca/en/canadian-cios-reveal-hiring-plans-for-first-half-of-2018?utm_campaign=Ambassador_Program&utm_medium=social&utm_source=voicestorm', 0, 'Canadian CIOs Reveal Hiring Plans For First Half of 2018', 'scintech', 0, '2017-12-26 14:25:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1212, 1, 'https://gbhackers.com/raspberry-pi-and-kali-linux/', 0, 'Building a Hacking Kit with Raspberry Pi and Kali Linux', 'scintech', 0, '2017-12-27 05:24:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1213, 1, 'https://www.thestar.com/news/canada/2017/12/28/14-minimum-wage-free-pharmacare-for-young-people-other-ontario-regulatory-changes-start-jan-1.html', 0, '$14 minimum wage, free pharmacare for young people, other Ontario regulatory changes start Jan. 1', 'society', 0, '2017-12-28 19:29:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1214, 1, 'https://www.entrepreneur.com/encyclopedia/bootstrapping', 0, 'Bootstrapping', 'society', 0, '2017-12-30 20:35:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1215, 1, 'https://www.vox.com/the-big-idea/2017/12/28/16823266/medical-treatments-evidence-based-expensive-cost-stents', 0, 'Why American doctors keep doing expensive procedures that donâ€™t work', 'society', 0, '2017-12-31 19:31:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1216, 1, 'https://seekingalpha.com/author/ted-ohashi/articles#regular_articles', 0, 'Ted Ohashi', 'society', 0, '2018-01-02 13:39:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1217, 1, 'https://www.nytimes.com/2018/01/02/upshot/us-health-care-expensive-country-comparison.html?_r=0', 0, 'Why the U.S. Spends So Much More Than Other Nations on Health Care', 'society', 0, '2018-01-03 12:18:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1218, 1, 'https://www.nytimes.com/2018/01/03/business/computer-flaws.html', 0, 'Researchers Discover Two Major Flaws In The World\'s Microprocessors', 'scintech', 0, '2018-01-04 03:13:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1219, 1, 'https://www.ctvnews.ca/health/health-canada-confirms-laced-chemicals-found-in-illicit-drugs-in-b-c-1.3300679', 0, 'Health Canada confirms laced chemicals found in illicit drugs in B.C.', 'society', 0, '2018-01-04 06:33:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1220, 1, 'http://www.telegraph.co.uk/news/2018/01/06/women-paid-less-half-men-britains-top-employers/', 0, 'Women paid less than half than men at some of Britain\'s top employers', 'society', 0, '2018-01-06 23:44:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1221, 1, 'http://www.cbc.ca/news/canada/saskatoon/saskatoon-marijuana-pot-legislation-insights-colorado-1.4475712', 0, 'What might be in store for Saskatoon once pot is legal?', 'society', 0, '2018-01-07 02:05:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1222, 1, 'http://www.motherjones.com/politics/2018/01/i-was-a-successful-journalist-when-a-doctor-first-handed-me-opioids/#', 0, 'I Was a Successful Journalist When a Doctor First Handed Me Opioids', 'society', 0, '2018-01-07 02:09:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1223, 1, 'http://www.cbc.ca/news/canada/toronto/small-businesses-support-minimum-wage-hikes-through-price-increases-1.4476108', 0, 'Small businesses try to support staff amid minimum wage hike', 'society', 0, '2018-01-07 02:12:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1224, 1, 'http://www.cbc.ca/news/technology/oceans-oxygen-canada-water-impact-1.4475867', 0, 'Oxygen disappearing from world\'s oceans, including Canada\'s', 'scintech', 0, '2018-01-07 04:33:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1225, 1, 'http://www.dw.com/en/us-astronaut-john-young-who-commanded-first-space-shuttle-mission-dies/a-42052717', 0, 'US astronaut John Young who commanded first space shuttle mission dies', 'worldnhistory', 0, '2018-01-07 04:34:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1226, 1, 'http://www.cbc.ca/news/canada/new-brunswick/meltdown-spectre-computer-exploit-1.4475301', 0, 'Chip flaws could affect every New Brunswicker with a computer', 'scintech', 0, '2018-01-07 04:34:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1227, 1, 'http://www.cbc.ca/news/health/flu-vaccine-potential-low-effectiveness-h3n2-1.4476100', 0, 'Flu vaccine may have low effectiveness against dominant strain, Canada\'s top public health doctor says', 'body', 0, '2018-01-07 04:35:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1228, 1, 'https://www.hollywoodreporter.com/news/four-women-accuse-paul-haggis-sexual-misconduct-including-two-rapes-1072015', 0, 'Four Women Accuse Paul Haggis of Sexual Misconduct, Including Two Rapes', 'society', 0, '2018-01-07 05:51:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1229, 1, 'https://www.investopedia.com/news/h1b-visa-issue-explained-msft-goog/?utm_source=personalized&utm_campaign=www.investopedia.com&utm_term=11830619&utm_medium=email', 0, 'The US H-1B Visa Issue Explained', 'society', 0, '2018-01-07 13:22:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1230, 1, 'https://hackernoon.com/im-harvesting-credit-card-numbers-and-passwords-from-your-site-here-s-how-9a8cb347c5b5', 0, 'Iâ€™m harvesting credit card numbers and passwords from your site. Hereâ€™s how.', 'scintech', 0, '2018-01-07 13:27:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1231, 1, 'https://work.qz.com/1173131/deadlines-dont-have-to-kill-creativity-according-to-harvard-research/', 0, 'Arbitrary deadlines are the enemy of creativity, according to Harvard research', 'society', 0, '2018-01-08 14:27:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1232, 1, 'https://www.linkedin.com/pulse/when-used-appropriately-escalation-good-thing-really-neil-campbell/', 0, 'When Used Appropriately, Escalation is a Good Thing - Really!', 'society', 0, '2018-01-08 15:47:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1233, 1, 'https://www.newyorker.com/magazine/2018/01/15/the-psychology-of-inequality?mbid=synd_digg', 0, 'The Psychology of Inequality', 'society', 0, '2018-01-09 13:52:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1234, 1, 'https://www.theatlantic.com/education/archive/2018/01/the-false-promises-of-worker-retraining/549398/', 0, 'The False Promises of Worker Retraining', 'society', 0, '2018-01-09 13:59:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1235, 1, 'https://www.atlasobscura.com/articles/john-young-corned-beef-sandwich-nasa-space', 0, 'Remembering the Astronaut Who Smuggled a Sandwich Into Space', 'scintech', 0, '2018-01-09 15:55:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1236, 1, 'https://www.eater.com/2018/1/5/16853818/rotisserie-chicken-costco-grocery-stores-price', 0, 'Why Costco Will Never Raise the Price of Rotisserie Chicken', 'society', 0, '2018-01-09 16:18:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1237, 1, 'https://www.nytimes.com/2018/01/09/magazine/why-are-our-most-important-teachers-paid-the-least.html', 0, 'Why Are Our Most Important Teachers Paid The Least?', 'society', 0, '2018-01-09 22:49:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1238, 1, 'http://digg.com/video/teach-arrested-asking-raise', 0, 'Teacher Arrested For Asking Why The Superintendent Is Receiving A Raise When School Employees Haven\'t', 'society', 0, '2018-01-09 22:56:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1239, 1, 'https://www.economist.com/news/asia/21734319-subsidising-parenthood-appears-work-wonders-small-town-japan-doubles-its-fertility-rate', 0, 'A small town in Japan doubles its fertility rate', 'worldnhistory', 0, '2018-01-09 22:59:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1240, 1, 'https://youtu.be/DXH2EGjRpY4', 0, 'How to Win with Game Theory & Defeat Smart Opponents', 'general', 0, '2018-01-10 02:59:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1241, 1, 'https://www.buzzfeed.com/johnstanton/from-gunshots-to-alleged-rapes-a-toxic-legacy-of-police?utm_term=.igP70ygAA9#.axmDMKzeek', 0, 'Native Americans Say Theyâ€™re Targets Of Shootings And Jailhouse Rapes By White Law Enforcement', 'society', 0, '2018-01-10 03:02:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1242, 1, 'https://www.vox.com/culture/2018/1/6/16855434/weinstein-reckoning-sexual-harassment-due-process-daphne-merkin-keillor-franken', 0, 'Are men accused of harassment being denied their due process? Or are the victims?', 'society', 0, '2018-01-10 03:08:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1243, 1, 'https://motherboard.vice.com/en_us/article/43q4jp/aadhaar-hack-insecure-biometric-id-system', 0, 'The World\'s Largest Biometric ID System Keeps Getting Hacked', 'scintech', 0, '2018-01-10 04:31:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1244, 1, 'http://www.bbc.com/future/story/20180108-when-personality-changes-from-bad-to-good', 0, 'When Brain Injuries Turn Someone\'s  Personality From Bad To Good', 'body', 0, '2018-01-10 16:40:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1245, 1, 'http://www.latimes.com/business/hollywood/la-fi-ct-james-franco-allegations-20180111-htmlstory.html', 0, 'Five women accuse actor James Franco of inappropriate or sexually exploitative behavior', 'society', 0, '2018-01-11 16:10:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1246, 1, 'http://www.cbc.ca/news/canada/montreal/hospital-overcrowding-investment-1.4485053', 0, 'Quebec investing $23M to ease hospital overcrowding', 'society', 0, '2018-01-12 23:38:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1247, 1, 'http://www.cbc.ca/news/canada/british-columbia/terry-lake-pot-opioids-1.4484687', 0, 'More research needed on pot use and hard-drug withdrawal symptoms, says former B.C. health minister', 'body', 0, '2018-01-12 23:41:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1248, 1, 'https://www.cnet.com/news/great-pyramid-of-giza-cheops-egypt-iron-throne-void/', 0, 'Real life \'Iron Throne\' may be hidden in Egypt', 'worldnhistory', 0, '2018-01-14 16:09:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1249, 1, 'https://youtu.be/jeghGhVdt9s', 0, 'Lock Picker Uses Gallium To Literally Crack An Aluminum Padlock', 'scintech', 0, '2018-01-14 16:32:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0);
INSERT INTO `articlelinks` (`linkid`, `linktype`, `link`, `imageid`, `title`, `category`, `articleid`, `createdate`, `revisedate`, `voteup`, `votedown`, `voteinternal`, `creatorid`, `numcomments`) VALUES
(1250, 1, 'https://theoutline.com/post/2904/honestly-fuck-harpers-katie-roiphe-shitty-men-in-media?zd=1', 0, 'Honestly, fuck Harperâ€™s', 'society', 0, '2018-01-14 17:22:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1251, 1, 'https://slate.com/business/2018/01/a-new-theory-for-why-americans-cant-get-a-raise.html', 0, 'Why Is It So Hard for Americans to Get a Decent Raise?', 'society', 0, '2018-01-17 07:17:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1252, 1, 'http://insiderbeauty.online/diet/thin/?voluumdata=deprecated&eda=deprecated&cep=3_4N9Zq0O4Mq3q1CRusA6_Wrtab5Gn8yft-B3gM6FVamB5RDFXv3L77ydc4pz_agcHJCcuyDo84RoJHv4m6xh4zUClP0wtmQFmXV2HHPuLEhrQMuNPCVoOuML1W6k8sSvfrJjodV1Xz3aItSAHvHC-ZdRJOIs8KEsbXnmi7KuQcnpu7VI_xU476DGXHzJhVUXuW5KJjUcPIgprNqncUUag&adname=BrsSHA', 0, '$4 Weight Loss Pill That Naturally Burns Fat Gets Biggest Deal In Shark Tank History', 'society', 0, '2018-01-17 10:15:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1253, 1, 'https://ca.finance.yahoo.com/news/lawsuit-u-accuses-nine-banks-rigging-canadian-rate-193558208--sector.html', 0, 'Lawsuit in U.S. accuses nine banks of rigging Canadian rate benchmark', 'society', 0, '2018-01-17 10:20:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1254, 1, 'http://www.news.com.au/national/breaking-news/victorian-plan-to-expand-cannabis-exports/news-story/2649bc993432eb85e2c68e8353cefa0e', 0, 'Victoria outlines medical marijuana plans', 'society', 0, '2018-01-17 13:07:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1255, 1, 'http://www.cbc.ca/news/canada/saskatchewan/enforcement-coming-to-illegal-marijuana-dispensaries-in-saskatoon-says-new-police-chief-1.4492262', 0, 'Enforcement coming to illegal marijuana dispensaries in Saskatoon, says new police chief', 'society', 0, '2018-01-18 03:19:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1256, 1, 'https://www.youtube.com/watch?v=aUw1_2xbYWM', 0, 'Woman Makes Paper By Hand', 'scintech', 0, '2018-01-20 21:47:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1257, 1, 'https://www.thecut.com/2018/01/maybe-men-will-be-scared-for-a-while.html', 0, 'Maybe Men Will Be Scared for a While But maybe to fear women is to begin seeing them as people.', 'society', 0, '2018-01-20 21:49:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1258, 1, 'https://www.topic.com/can-you-arrest-people-before-they-commit-crimes', 0, 'Can You Arrest People Before They Commit Crimes?', 'society', 0, '2018-01-21 02:45:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1259, 1, 'https://qz.com/1175923/how-anti-abortion-laws-are-part-of-the-war-on-the-poorest-americans/', 0, 'Being denied an abortion may push more people into poverty', 'society', 0, '2018-01-21 03:18:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1260, 1, 'https://www.vice.com/en_us/article/mb3ww8/inside-the-private-mens-club-where-women-can-only-speak-when-spoken-to', 0, 'Inside the Private Men\'s Club Where Women Can Only Speak When Spoken To', 'society', 0, '2018-01-25 01:29:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1261, 1, 'http://digg.com/video/in-praise-bias', 0, 'A Defense Of Bias In Media', 'society', 0, '2018-01-25 11:05:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1262, 1, 'https://newrepublic.com/article/146710/injustice-algorithms', 0, 'The Injustice of Algorithms', 'society', 0, '2018-01-26 10:54:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1263, 1, 'https://www.nytimes.com/2018/01/23/magazine/how-arafat-eluded-israels-assassination-machine.html', 0, 'How Arafat Eluded Israelâ€™s Assassination Machine', 'worldnhistory', 0, '2018-01-26 13:58:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1264, 1, 'http://digg.com/2018/jordan-peterson-book-review', 0, 'Jordan Peterson Is Having A Moment â€” We Should Ignore It', 'society', 0, '2018-01-27 07:17:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1265, 1, 'https://www.theguardian.com/news/2018/jan/25/murder-in-hampstead-did-secret-trial-put-wrong-man-in-jail-allan-chappelow', 0, 'Murder in Hampstead: did a secret trial put the wrong man in jail?', 'society', 0, '2018-01-27 07:19:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1266, 1, 'http://digg.com/video/foxes-living-under-storage-containers', 0, 'A Workplace Infested With Foxes Is The Best Work Problem Anyone Has Ever Had', 'general', 0, '2018-01-28 11:14:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1267, 1, 'https://www.nytimes.com/2018/01/30/world/africa/raila-odinga-kenya.html', 0, 'Kenyans Name a â€˜Peopleâ€™s President,â€™ and TV Broadcasts Are Cut', 'worldnhistory', 0, '2018-01-30 13:49:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1268, 1, 'http://www.cbc.ca/news/canada/edmonton/cambodian-charges-against-2-canadian-women-over-pornographic-dance-party-could-lead-to-year-in-jail-1.4509047', 0, 'Cambodian charges against 2 Canadian women over \'pornographic\' dance party could lead to year in jail', 'worldnhistory', 0, '2018-01-30 13:49:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1269, 1, 'http://www.businessinsider.com/basic-income-study-kenya-redefining-nature-of-work-2018-1', 0, 'Thousands of people in Kenya are getting basic income for 12 years in an experiment that could redefine social', 'worldnhistory', 0, '2018-01-30 13:55:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1270, 1, 'http://www.cbc.ca/news/canada/toronto/yonge-wellesley-stabbing-1.4509927', 0, 'Man dies in hospital after stabbing near Yonge and Wellesley', 'society', 0, '2018-01-30 14:02:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1271, 1, 'http://www.cbc.ca/news/canada/saskatoon/colten-boushie-gerald-stanley-trial-begins-saskatchewan-1.4501897', 0, 'Gerald Stanley trial on 2nd-degree murder charge gets underway in Saskatchewan', 'society', 0, '2018-01-30 14:05:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1272, 1, 'http://money.cnn.com/2017/11/09/news/economy/saudi-arabia-100-billion-corruption/index.html', 0, 'Saudi Arabia\'s $100 billion corruption scandal', 'society', 0, '2018-01-30 18:30:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1273, 1, 'https://www.ctvnews.ca/canada/1-1b-lawsuit-alleges-horrors-at-canada-s-indian-hospitals-1.3781636', 0, '$1.1B lawsuit alleges horrors at Canada\'s \'Indian hospitals\'  ', 'society', 0, '2018-01-31 13:52:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1274, 1, 'https://www.outsideonline.com/2277166/hostile-environment', 0, 'An investigation of sexual harassment in outdoor workplaces, where unwanted advances, discrimination & assault', 'society', 0, '2018-02-01 02:40:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1275, 1, 'https://www.nbcnews.com/news/world/poland-s-senate-backs-holocaust-speech-law-n843581', 0, 'Polandâ€™s Senate backs Holocaust speech law', 'worldnhistory', 0, '2018-02-01 11:06:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1276, 1, 'https://ca.yahoo.com/news/fleeing-bank-robbery-suspects-caught-155642805.html', 0, 'Fleeing bank robbery suspects caught after stopping at a Tim Hortons drive-thru', 'society', 0, '2018-02-01 11:06:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1277, 1, 'https://www.yahoo.com/news/apos-couldn-apos-t-hide-044549546.html', 0, '\'They Couldn\'t Hide all the Death.\' 5 More Rohingya Mass Graves Found in Myanmar', 'worldnhistory', 0, '2018-02-01 13:30:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1278, 1, 'http://www.bbc.com/news/world-africa-42905290', 0, 'Kenya TV shutdown: Court suspends ban imposed over Odinga \'inauguration\'', 'worldnhistory', 0, '2018-02-01 13:31:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1279, 1, 'https://www.npr.org/sections/thetwo-way/2018/01/31/582254895/whale-hello-orcas-can-imitate-human-speech-researchers-find', 0, 'Whale Hello: Orcas Can Imitate Human Speech, Researchers Find', 'worldnhistory', 0, '2018-02-01 13:40:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1280, 1, 'https://news.nationalgeographic.com/2018/02/maya-laser-lidar-guatemala-pacunam/', 0, 'Exclusive Laser Scans Reveal Maya Megalopolis Below Guatemalan Jungle', 'worldnhistory', 0, '2018-02-03 13:48:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1281, 1, 'https://globalnews.ca/news/2898641/how-much-is-your-doctor-making-what-you-need-to-know-about-canadas-physician-workforce/', 0, 'How much is your doctor making? What you need to know about Canadaâ€™s physician workforce', 'society', 0, '2018-02-03 23:58:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1282, 1, 'http://www.cbc.ca/news/politics/female-genital-mutilation-benin-bibeau-1.4520481', 0, 'Canada spends $3M to stop female genital mutilation in African nation of Benin', 'worldnhistory', 0, '2018-02-06 15:38:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1283, 1, 'https://www.ctvnews.ca/business/global-markets-tumble-after-wall-street-battering-1.3791196', 0, 'Global markets tumble after Wall Street battering  ', 'worldnhistory', 0, '2018-02-06 15:41:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1284, 1, 'https://slate.com/news-and-politics/2018/02/what-if-the-iran-deal-was-a-mistake.html', 0, 'What if the Iran Deal Was a Mistake?', 'society', 0, '2018-02-06 17:11:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1285, 1, 'http://www.businessinsider.com/r-unilever-threatens-online-ad-cuts-to-clean-up-internet-2018-2', 0, 'Unilever threatens online ad cuts to clean up internet', 'society', 0, '2018-02-12 14:34:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1286, 1, 'https://www.cnn.com/2018/02/11/health/aetna-california-investigation/index.html', 0, 'CNN Exclusive: California launches investigation following stunning admission by Aetna medical director', 'society', 0, '2018-02-12 14:35:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1287, 1, 'http://www.foxnews.com/health/2018/02/12/texas-mom-dies-from-flu-after-skipping-on-meds-deemed-too-costly-report.html', 0, 'Texas mom dies from flu after skipping on meds deemed too costly', 'worldnhistory', 0, '2018-02-12 14:39:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1288, 1, 'http://www.wfaa.com/news/nation-world/why-are-people-outside-high-risk-groups-dying-from-the-flu/517518718', 0, 'Why are people outside high-risk groups dying from the flu?', 'society', 0, '2018-02-12 14:39:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1289, 1, 'http://digg.com/2018/west-virginia-woman-ejected-donors', 0, 'Pointing Out That Politicians Took Money From Corporations Will Get You Ejected From A Public Hearing In West ', 'society', 0, '2018-02-13 15:42:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1290, 1, 'http://www.ibtimes.co.uk/fking-moron-twitter-drags-trumps-cruel-plan-swap-food-stamps-blue-apron-type-boxes-1661304', 0, 'Prez Trumps plan to swap food stamps for food boxes', 'society', 0, '2018-02-14 16:05:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1291, 1, 'http://www.cbc.ca/news/world/south-african-police-raid-family-guptas-president-zuma-1.4534587', 0, 'After order to resign, South African president says he has been victimized', 'worldnhistory', 0, '2018-02-14 16:06:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1292, 1, 'https://www.brentozar.com/archive/2016/01/get-first-full-time-dba-job/', 0, 'How to Get Your Very First Full Time DBA Job', 'scintech', 0, '2018-02-15 02:16:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1293, 1, 'http://www.cbc.ca/news/canada/calgary/john-mcnamara-hiv-1.4535962', 0, 'Calgarian who didn\'t tell partners he had HIV pleads guilty to 6 counts of sexual assault', 'society', 0, '2018-02-15 10:10:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1294, 1, 'https://apnews.com/a6fd450470d4464ab423b8b3a911b42d/Florida-teen-charged-with-17-murder-counts-in-school-attack', 0, 'Florida teen charged with 17 murders legally bought AR-15', 'society', 0, '2018-02-15 14:11:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1295, 1, 'http://www.cbc.ca/news/world/cyril-ramaphosa-elected-south-africa-s-new-president-1.4536501', 0, 'Cyril Ramaphosa elected South Africa\'s new president', 'worldnhistory', 0, '2018-02-15 14:45:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1296, 1, 'https://www.gartner.com/newsroom/id/492112', 0, 'Gartner Says More Than 50 Percent of Data Warehouse Projects Will Have Limited Acceptance or Will Be Failures ', 'scintech', 0, '2018-02-15 18:54:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1297, 1, 'https://www.timmitchell.net/post/2017/01/10/why-data-warehouse-projects-fail/', 0, 'Why Data Warehouse Projects Fail', 'scintech', 0, '2018-02-15 18:55:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1298, 1, 'https://www.ellicium.com/data-warehouse-implementation-mistakes/', 0, '5 Data Warehouse implementation mistakes to avoid in Big Data Projects', 'scintech', 0, '2018-02-15 18:55:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1299, 1, 'https://www.networkworld.com/article/3170137/cloud-computing/why-big-data-projects-fail-and-how-to-make-2017-different.html', 0, 'Why big data projects fail and how to make 2017 different', 'scintech', 0, '2018-02-15 18:56:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1300, 1, 'http://searchoracle.techtarget.com/tip/Why-data-warehousing-projects-fail', 0, 'Why data warehousing projects fail', 'general', 0, '2018-02-15 18:57:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1301, 1, 'http://www.cbc.ca/news/politics/ndp-policy-convention-1.4538953', 0, 'NDP president offers apology for party\'s handling of harassment allegations', 'society', 0, '2018-02-17 13:21:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1302, 1, 'http://www.cbc.ca/news/canada/calgary/cannabis-retail-regulations-alberta-1.4538542', 0, 'Alberta expects to license 250 cannabis stores in first year', 'society', 0, '2018-02-17 13:22:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1303, 1, 'http://www.cbc.ca/news/canada/saskatchewan/hiv-testing-increasing-saskatchewan-first-nation-1.4539239', 0, 'New HIV screening method leads to apparent spike in testing at Sask. First Nations', 'society', 0, '2018-02-17 13:23:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1304, 1, 'http://www.cbc.ca/news/canada/nova-scotia/nova-scotia-doctor-recruitment-british-columbia-1.4535748', 0, 'What Nova Scotia doctor recruiters can learn from B.C. as they target the U.K.', 'society', 0, '2018-02-17 13:28:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1305, 1, 'http://digg.com/2018/west-virginia-woman-ejected-donors', 0, 'Pointing Out That Politicians Took Money From Corporations Will Get You Ejected From A Public Hearing In West', 'society', 0, '2018-02-18 12:35:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1306, 1, 'http://www.cbc.ca/news/canada/newfoundland-labrador/anne-norris-murder-trial-day-17-1.4542867', 0, 'Psychiatrist cross-examined on Day 17 of Anne Norris murder trial', 'society', 0, '2018-02-20 15:09:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1307, 1, 'http://www.cbc.ca/news/canada/saskatoon/michelle-obama-saskatoon-march-tickets-on-sale-friday-1.4541233', 0, 'Michelle Obama to speak in Saskatoon in March', 'society', 0, '2018-02-20 15:50:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1308, 1, 'http://www.independent.co.uk/news/science/marijuana-overdose-baby-colorado-dr-christopher-hoyte-dr-thomas-nappe-a8062256.html', 0, 'Babys death becomes the first to be associated with cannabis in the US, report states', 'body', 0, '2018-02-21 02:17:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1309, 1, 'https://arstechnica.com/science/2018/02/supplements-are-a-30-billion-racket-heres-what-experts-actually-recommend/?mbid=synd_digg', 0, 'Supplements are a $30 billion racketâ€”hereâ€™s what experts actually recommend', 'body', 0, '2018-02-21 08:14:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1310, 1, 'http://www.nybooks.com/daily/2018/02/19/congo-for-the-congolese/', 0, 'Congo for the Congolese', 'worldnhistory', 0, '2018-02-21 11:43:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1311, 1, 'http://www.cbc.ca/news/business/trans-pacific-partnership-final-text-release-1.4544521', 0, 'Canada welcomes release of final text of CPTPP deal', 'worldnhistory', 0, '2018-02-21 14:22:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1312, 1, 'http://www.cbc.ca/news/technology/mexico-flooded-cave-1.4543416', 0, 'Ancient human, giant sloth remains found in world\'s biggest flooded cave', 'scintech', 0, '2018-02-21 14:27:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1313, 1, 'http://www.theparanormalseekers.ca/ghost-road---port-perry.html', 0, 'GHOST ROAD - PORT PERRY', 'society', 0, '2018-02-23 02:22:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1314, 1, 'https://social.technet.microsoft.com/wiki/contents/articles/34445.mvc-asp-net-identity-customizing-for-adding-profile-image.aspx#Step_6_Edit_Register_view_to_add_our_upload_image', 0, 'MVC ASP.NET: Identity customizing for adding profile image', 'scintech', 0, '2018-02-23 04:31:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1315, 1, 'https://www.nature.com/articles/d41586-018-02315-4', 0, 'Doubts raised over Australiaâ€™s plan to release herpes to wipe out carp', 'scintech', 0, '2018-02-25 01:42:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1316, 1, 'https://www.nature.com/articles/d41586-018-02170-3', 0, 'Sex and drugs and self-control: how the teen brain navigates risk', 'sexndating', 0, '2018-02-25 17:51:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1317, 1, 'http://www.greaterkashmir.com/news/life-style/story/276965.html', 0, 'New mind-reading tech can tell who you are thinking about!', 'scintech', 0, '2018-02-26 13:49:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1318, 1, 'https://www.youtube.com/watch?v=-G1wcnNuCNE', 0, '12 Chilling Photos Taken Right Before Passing On', 'worldnhistory', 0, '2018-02-27 11:00:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1319, 1, 'https://www.washingtonpost.com/news/capital-weather-gang/wp/2018/02/26/north-pole-surges-above-freezing-in-the-dead-of-winter-stunning-scientists/?utm_term=.1739e33ccf10', 0, 'North Pole surges above freezing in the dead of winter, stunning scientists', 'scintech', 0, '2018-02-27 11:02:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1320, 1, 'https://motherboard.vice.com/en_us/article/qven97/adam-reiss-hubble-telescope-expanding-universe', 0, 'How Cosmologists Determined That the Universe Is Expanding Faster Than Anyone Thought', 'scintech', 0, '2018-02-28 21:58:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1321, 1, 'https://www.wired.com/story/why-are-there-few-women-in-tech-watch-a-recruiting-session/?mbid=synd_digg', 0, 'WHY ARE THERE FEW WOMEN IN TECH (Because they are manipulative and cunning)? WATCH A RECRUITING SESSION', 'society', 0, '2018-03-02 12:05:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1322, 1, 'https://www.vice.com/en_us/article/437573/blacks-were-enslaved-well-into-the-1960s?utm_source=vicetwitterus', 0, 'Blacks Were Enslaved Well into the 1960s', 'society', 0, '2018-03-02 12:08:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1323, 1, 'https://www.nytimes.com/2018/03/03/business/economy/tariff-blue-collar.html', 0, 'Trumpâ€™s Tariff Plan Leaves Blue-Collar Winners and Losers', 'society', 0, '2018-03-05 13:37:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1324, 1, 'http://www.cbc.ca/news/canada/toronto/bruce-mcarthur-latest-body-toronto-police-1.4561794', 0, 'Toronto police make grisly discovery of 7th set of human remains in Bruce McArthur\'s planters', 'society', 0, '2018-03-05 15:29:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1325, 1, 'http://www.cbc.ca/news/canada/hamilton/hamilton-mob-mischief-1.4561615', 0, 'Masked mob dressed in black vandalizes streets of Hamilton', 'society', 0, '2018-03-05 15:31:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1326, 1, 'http://www.labmanager.com/news/2018/03/bubbles-of-life-from-the-past#.Wp1j_ejwaUk', 0, 'Bubbles of Life from the Past', 'scintech', 0, '2018-03-05 15:39:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1327, 1, 'http://www.cbc.ca/news/canada/toronto/york-university-strike-faculty-cupe-1.4561828', 0, 'York University contract staff kicks off strike action on Monday with mass rally', 'society', 0, '2018-03-05 17:17:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1328, 1, 'https://ca.finance.yahoo.com/news/cra-slammed-apos-reprehensible-malicious-235227560.html', 0, 'CRA slammed for reprehensible and malicious prosecution of B.C. couple', 'society', 0, '2018-03-07 05:32:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1329, 1, 'https://www.washingtonpost.com/world/asia_pacific/north-korean-leader-kim-jong-un-has-invited-president-trump-to-a-meeting/2018/03/08/021cb070-2322-11e8-badd-7c9f29a55815_story.html?utm_term=.7a569330af44', 0, 'Trump accepts invitation to meet with North Korean leader Kim Jong Un', 'worldnhistory', 0, '2018-03-09 02:01:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1330, 1, 'https://www.theatlantic.com/entertainment/archive/2018/03/how-to-lose-your-job-from-sexual-harassment-in-33-easy-steps/555197/', 0, 'How to Lose Your Job From Sexual Harassment in 33 Easy Steps', 'sexndating', 0, '2018-03-10 00:47:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1331, 1, 'https://www.theguardian.com/us-news/2018/mar/09/martin-shkreli-jail-sentence-how-long-pharma-bro-court-trial', 0, 'Martin Shkreli jailed: \'Pharma Bro\' sentenced to seven years for fraud', 'society', 0, '2018-03-10 04:52:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1332, 1, 'https://www.nytimes.com/2018/03/09/nyregion/al-sharpton-reconsidered.html?smid=tw-share', 0, 'Al Sharpton, reconsidered', 'society', 0, '2018-03-10 04:55:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1333, 1, 'http://digg.com/video/resilience', 0, 'You Would Actually Probably Be Fine If You Lost Everything You Cherish In Life', 'general', 0, '2018-03-10 12:17:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1334, 1, 'https://www.vox.com/first-person/2018/3/8/17087628/sexual-assault-marriage-metoo', 0, 'We need to talk about sexual assault in marriage', 'sexndating', 0, '2018-03-11 12:31:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1335, 1, 'http://www.chicagotribune.com/news/nationworld/ct-china-xi-jinping-amendment-20180311-story.html', 0, 'China makes historic move to allow Xi to rule indefinitely', 'worldnhistory', 0, '2018-03-11 13:41:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1336, 1, 'https://www.washingtonpost.com/news/to-your-health/wp/2018/03/10/dentists-keep-dying-of-this-deadly-lung-disease-the-cdc-cant-figure-out-why/?utm_term=.ec61aa168a7e', 0, 'Dentists keep dying of this lung disease. The CDC canâ€™t figure out why.', 'scintech', 0, '2018-03-11 13:47:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1337, 1, 'https://nypost.com/2018/03/10/disease-x-could-be-the-worlds-worst-nightmare/', 0, 'Disease X', 'scintech', 0, '2018-03-11 13:50:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1338, 1, 'http://www.techtimes.com/articles/222772/20180310/young-woman-who-gouged-own-eyes-out-while-on-meth-shares-her-story.htm', 0, 'Young Woman Who Gouged Own Eyes Out While On Meth Shares Her Story', 'society', 0, '2018-03-11 13:50:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1339, 1, 'https://www.theverge.com/2017/3/8/14835840/sam-maggs-wonder-women-stem-role-models-gender-sexism', 0, 'Why it\'s so important for girls to find role models in female scientists', 'society', 0, '2018-03-11 15:58:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1340, 1, 'http://www.bbc.com/future/story/20180306-a-spa-where-patients-bathe-in-radiactive-water', 0, 'A Spa Where Patients Bath In Radioactive Water', 'worldnhistory', 0, '2018-03-11 16:34:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1341, 1, 'https://theslot.jezebel.com/scenes-from-a-strike-1823649566', 0, 'Woman\'s Rights Protests', 'worldnhistory', 0, '2018-03-11 21:47:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1342, 1, 'https://www.youtube.com/watch?v=ESyJop31cmY', 0, 'The Broccoli Tree: A Parable', 'worldnhistory', 0, '2018-03-11 22:10:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1343, 1, 'https://www.npr.org/sections/thetwo-way/2018/03/13/221053162/stephen-hawking-who-awed-both-scientists-and-the-public-dies', 0, 'Stephen Hawking, Who Awed Both Scientists And The Public, Dies', 'worldnhistory', 0, '2018-03-14 21:05:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1344, 1, 'http://digg.com/2018/theranos-lawsuit-elizabeth-holmes-highlights', 0, 'Theranos CEO Elizabeth Holmes Charged With Massive Fraud â€” Here Are The Highlights', 'society', 0, '2018-03-14 21:09:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1345, 1, 'https://www.cnn.com/2018/03/14/health/scott-kelly-dna-nasa-twins-study/index.html', 0, 'Astronauts DNA no longer matches that of his identical twin, NASA finds', 'scintech', 0, '2018-03-14 21:11:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1346, 1, 'https://www.youtube.com/watch?time_continue=491&v=AHX6tHdQGiQ', 0, 'Ink Cartridges Are A Scam', 'scintech', 0, '2018-03-16 15:10:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1347, 1, 'https://www.theverge.com/2018/3/16/17130366/china-social-credit-travel-plane-train-tickets', 0, 'China will ban people with poor â€˜social creditâ€™ from planes and trains', 'worldnhistory', 0, '2018-03-17 21:30:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1348, 1, 'http://digg.com/video/cotton-candy-eating-contest', 0, 'Now This Is How You Win A Cotton Candy Eating Contest', 'general', 0, '2018-03-17 21:33:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1349, 1, 'https://www.popsci.com/smart-animals?src=SOC&dom=tw', 0, 'Seven creatures with skills that easily beat humans', 'scintech', 0, '2018-03-19 17:18:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1350, 1, 'https://null-byte.wonderhowto.com/how-to/essential-skills-becoming-master-hacker-0154509/', 0, 'The Essential Skills to Becoming a Master Hacker', 'scintech', 0, '2018-03-19 20:31:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1351, 1, 'http://www.cbc.ca/news/entertainment/the-crown-gender-pay-gap-1.4584609', 0, 'The Crown producers apologize after Claire Foy, Matt Smith pay disparity uproar', 'society', 0, '2018-03-21 00:22:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1352, 1, 'http://toofab.com/2018/03/21/robin-williams-mork-and-mindy-co-star-flashed-humped-bumped-so-much-fun/', 0, 'Robin Williams Mork & Mindy Co-Star Says He Flashed, Humped Her On Set and It Was So Much Fun', 'society', 0, '2018-03-21 16:23:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1353, 1, 'http://torontosun.com/news/local-news/three-listeria-cases-linked-to-druxys-location-at-toronto-hospital', 0, 'Three Listeria cases linked to Druxys location at Toronto hospital', 'society', 0, '2018-03-21 16:24:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1354, 1, 'http://www.cbc.ca/news/business/orbitz-data-breach-1.4583985', 0, 'Orbitz hack exposed data of 880,000 customers in 2016 and 2017', 'worldnhistory', 0, '2018-03-21 16:39:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1355, 1, 'http://www.cbc.ca/amp/1.4586659', 0, '\'Major breach of trust\': Zuckerberg says Facebook made mistakes on Cambridge Analytica', 'scintech', 0, '2018-03-22 08:48:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1356, 1, 'http://nationalpost.com/pmn/news-pmn/peru-president-undone-by-corruption-scandals-he-vowed-to-end', 0, 'Peru president undone by corruption scandals he vowed to end', 'worldnhistory', 0, '2018-03-22 08:49:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1357, 1, 'http://www.cbc.ca/news/canada/afghanistan-taliban-women-abuse-refugee-1.4586628', 0, 'What type of man could hurt somebody like me? Woman shot in face in Afghanistan settles into life in B.C.', 'worldnhistory', 0, '2018-03-22 08:50:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1358, 1, 'http://www.abplive.in/world-news/trump-to-announce-trade-sanctions-on-china-672206?ref=hp_news_7&rs_type=internal&rs_origin=home&rs_medium=news&rs_index=7&ani', 0, 'Trump to announce trade sanctions on China', 'worldnhistory', 0, '2018-03-22 08:51:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1359, 1, 'https://ca.news.yahoo.com/stupid-can-get-duterte-slams-canada-botched-deal-193533024.html', 0, 'How stupid can you get?: Duterte slams Canada over botched deal', 'worldnhistory', 0, '2018-03-22 18:11:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1360, 1, 'https://features.propublica.org/ibm/ibm-age-discrimination-american-workers/', 0, 'CUTTING OLD HEADS AT IBM', 'society', 0, '2018-03-23 17:24:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1361, 1, 'http://map.norsecorp.com', 0, 'Live DDOS Map', 'scintech', 0, '2018-03-24 08:39:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1362, 1, 'https://www.vox.com/2018/3/22/17139230/columbine-parkland-gun-control-march-for-our-lives-2018', 0, 'They survived Columbine. Then came Sandy Hook. And Parkland.', 'worldnhistory', 0, '2018-03-24 20:44:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1363, 1, 'http://digg.com/2018/craigslist-personals-shutdown', 0, 'What To Know About The Terrible Anti-Trafficking Bill That Forced Craigslist To Shut Down Its Personals.', 'worldnhistory', 0, '2018-03-24 20:45:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1364, 1, 'https://www.nature.com/articles/d41586-018-03267-5', 0, 'When antibiotics turn toxic', 'scintech', 0, '2018-03-25 17:33:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1365, 1, 'https://www.theverge.com/2018/3/23/17155204/south-korea-government-computer-shut-down-employee-overtime', 0, 'The South Korean government will shut down employee computers so they leave on time', 'worldnhistory', 0, '2018-03-26 03:46:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1366, 1, 'https://www.citylab.com/equity/2018/03/how-does-a-violent-crime-spree-affect-a-community/556265/', 0, 'How Does a Violent-Crime Spree Affect a Community?', 'society', 0, '2018-03-26 04:53:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1367, 1, 'https://en.wikipedia.org/wiki/List_of_mythological_objects', 0, 'List of mythological objects', 'worldnhistory', 0, '2018-03-26 11:54:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1368, 1, 'http://digg.com/2018/training-for-all-major-comptia-exams', 0, 'Pass All Major CompTIA Exams For Less Than $5 Per Training Course', 'scintech', 0, '2018-03-27 03:38:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1369, 1, 'https://globalnews.ca/news/3317421/recent-atm-thefts-prompts-security-reminder-from-edmonton-police/', 0, 'Recent ATM thefts prompt security reminder from Edmonton police', 'society', 0, '2018-03-27 09:22:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1370, 1, 'http://www.bbc.com/travel/story/20180326-caught-between-two-seas-indias-resilient-ghost-town', 0, 'India\'s Resilient Ghost Town', 'worldnhistory', 0, '2018-03-27 14:04:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1371, 1, 'http://digg.com/video/singapore-facebook-exec', 0, 'Singaporean Politician Delivers Scathing Smackdown To Facebook Exec For Trying To Evade Questions', 'worldnhistory', 0, '2018-03-27 19:19:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1372, 1, 'https://www.buzzfeed.com/jenhchoi/i-wanted-to-love-paris-but-it-didnt-love-me?utm_term=.xbjyN908P#.jpJP1MylX', 0, 'I Wanted To Love Paris, But It Didnâ€™t Love Me', 'worldnhistory', 0, '2018-03-28 18:30:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1373, 1, 'https://www.nytimes.com/2018/03/28/world/americas/french-waiter-rude.html', 0, 'Is Your Waiter Rude? Or Simply French?', 'society', 0, '2018-03-29 05:00:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1374, 1, 'https://qz.com/1235824/you-can-actually-learn-to-be-wise-and-it-can-help-you-feel-less-lonely/', 0, 'You can actually learn to be wise, and it can help you feel less lonely', 'society', 0, '2018-03-29 12:51:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1375, 1, 'https://www.wired.com/story/the-case-of-the-missing-dark-matter/?mbid=synd_digg', 0, 'THE CASE OF THE MISSING DARK MATTER', 'scintech', 0, '2018-03-29 12:53:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1376, 1, 'http://digg.com/2018/fastest-growing-cities-map', 0, 'The World\'s Fastest Growing Cities, Mapped', 'worldnhistory', 0, '2018-03-29 12:53:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1377, 1, 'https://gizmodo.com/elon-musks-neuralink-sought-to-open-an-animal-testing-f-1823167674', 0, 'Elon Musk\'s Neuralink Sought to Open an Animal Testing Facility in San Francisco', 'scintech', 0, '2018-03-29 12:54:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1378, 1, 'https://www.fastcodesign.com/90165549/the-next-great-building-material-it-could-be-sand-from-deserts', 0, 'The Next Great Building Material? It Could Be Sand From Deserts', 'scintech', 0, '2018-03-29 16:22:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1379, 1, 'http://www.cbc.ca/news/business/under-armour-data-breach-1.4599794', 0, 'Under Armour says data breach affected 150 million users', 'scintech', 0, '2018-03-30 16:43:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1380, 1, 'https://www.engadget.com/2018/03/30/facebook-fighting-abuse-at-scale/', 0, 'Facebook is hosting an online abuse summit with other tech leaders', 'society', 0, '2018-03-30 17:05:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1381, 1, 'https://www.dailydot.com/layer8/veterans-affairs-sexual-harassment-payouts/', 0, 'Dept. of Veterans Affairs has paid $8.7 million in sexual harassment settlements', 'society', 0, '2018-03-30 17:17:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1382, 1, 'https://www.youtube.com/watch?time_continue=552&v=3BNg4fDJC8A', 0, 'How This Guy Folds and Flies World Record Paper Airplanes | WIRED', 'scintech', 0, '2018-03-30 17:57:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1383, 1, 'https://jalopnik.com/things-are-not-looking-good-for-tesla-right-now-1824174945', 0, 'Things Are Not Looking Good For Tesla Right Now', 'scintech', 0, '2018-03-31 05:18:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1384, 1, 'http://digg.com/2018/myfitnesspal-under-armour-data-breach', 0, 'In Case You Missed It, One Of The Largest Data Breaches In History Was Just Announced', 'scintech', 0, '2018-03-31 06:54:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1385, 1, 'https://globalnews.ca/news/4115602/us-visa-social-media-identities/', 0, 'U.S. visa applicants may soon be asked for social media identities: State Dept', 'scintech', 0, '2018-03-31 06:56:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1386, 1, 'http://www.cbc.ca/news/canada/hamilton/police-investigate-alleged-group-sexual-assault-in-niagara-falls-1.4601561', 0, 'Police investigate alleged group sexual assault in Niagara Falls', 'society', 0, '2018-04-01 20:07:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1387, 1, 'https://motherboard.vice.com/en_us/article/a3y39j/diy-euthanasia-movement-philip-nitschke-exit-international', 0, 'Rise of the DIY Death Machines', 'scintech', 0, '2018-04-02 07:06:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1388, 1, 'http://www.cbc.ca/news/world/youtube-shooting-suspect-1.4604163', 0, 'Police work on theory YouTube shooter motivated by grudge against company', 'society', 0, '2018-04-05 02:43:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1389, 1, 'http://www.cbc.ca/news/world/israel-africans-netanyahu-reversal-stoffel-1.4604219', 0, 'Netanyahus reversal on African migrants draws scorn', 'worldnhistory', 0, '2018-04-05 04:50:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1390, 1, 'https://www.washingtonpost.com/opinions/jill-mccabe-the-president-attacked-my-reputation-its-time-to-set-the-record-straight/2018/04/02/e6bbcf66-366b-11e8-8fd2-49fe3c675a89_story.html?utm_term=.b65092ba5ba7', 0, 'Jill McCabe: The president attacked my reputation. Itâ€™s time to set the record straight.', 'society', 0, '2018-04-05 13:37:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1391, 1, 'https://www.quantamagazine.org/new-brain-maps-with-unmatched-detail-may-change-neuroscience-20180404/', 0, 'New Brain Maps With Unmatched Detail May Change Neuroscience', 'scintech', 0, '2018-04-06 13:26:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1392, 1, 'http://www.wweek.com/news/2018/04/03/in-1984-the-rajneeshees-bused-3000-homeless-people-to-live-in-their-oregon-compound-our-reporter-was-one-of-them/', 0, 'In 1984, the Rajneeshees Bused 3,000 Homeless People to Live in Their Oregon Compound.', 'worldnhistory', 0, '2018-04-06 13:27:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1393, 1, 'https://medium.com/s/one-weird-trick/i-can-see-your-lips-moving-why-what-you-hear-is-affected-by-what-you-see-f800abbaca75', 0, 'I Can See Your Lips Movingâ€”Why What You Hear Is Affected By What You See', 'scintech', 0, '2018-04-06 13:29:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1394, 1, 'https://www.nature.com/articles/d41586-018-03916-9', 0, 'Squeaky clean mice could be ruining research', 'scintech', 0, '2018-04-07 16:01:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1395, 1, 'https://www.wired.com/story/fin7-carbanak-hacking-group-behind-a-string-of-big-breaches/?mbid=synd_digg', 0, 'THE BILLION-DOLLAR HACKING GROUP BEHIND A STRING OF BIG BREACHES', 'worldnhistory', 0, '2018-04-07 16:03:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1396, 1, 'https://gizmodo.com/genetics-research-is-failing-most-of-the-worlds-populat-1824032089', 0, 'Genetics Research Is Failing Most of the World\'s Population', 'scintech', 0, '2018-04-07 16:04:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1397, 1, 'https://www.hollywoodreporter.com/thr-esq/has-man-sued-you-a-copyright-troll-takes-hollywood-1099156', 0, 'Has This Man Sued You? A Copyright Troll Takes on Hollywood', 'society', 0, '2018-04-07 16:06:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1398, 1, 'http://digg.com/2018/new-facebook-rules-political-ads', 0, 'Mark Zuckerberg Endorses The Regulation Of Facebook Ahead Of Congressional Testimony', 'society', 0, '2018-04-07 16:10:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1399, 1, 'https://www.cnbc.com/2018/04/05/facebook-building-8-explored-data-sharing-agreement-with-hospitals.html', 0, 'Facebook sent a doctor on a secret mission to ask hospitals to share patient data', 'society', 0, '2018-04-09 04:45:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1400, 1, 'https://www.theguardian.com/society/2018/apr/05/white-gangs-rise-simon-city-royals-mississippi-chicago', 0, 'Dangerous, growing, yet unnoticed: the rise of Americas white gangs', 'society', 0, '2018-04-09 04:51:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1401, 1, 'http://cnnlocalnews.com/index-2.html', 0, 'Elon Musk Gives Away Fortune To Canadian Citizens', 'society', 0, '2018-04-09 04:59:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1402, 1, 'http://www.cbc.ca/news/technology/fbi-backpage-seizure-adult-escort-services-crackdown-classifieds-1.4610067', 0, 'FBI, U.S. authorities seize Backpage.com in crackdown', 'society', 0, '2018-04-09 05:51:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1403, 1, 'https://www.theverge.com/2018/4/5/17199210/blockchain-coin-center-gdpr-europe-bitcoin-data-privacy', 0, 'Major blockchain group says Europe should exempt Bitcoin from new data privacy rule', 'worldnhistory', 0, '2018-04-09 05:54:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1404, 1, 'https://www.politico.com/story/2018/04/06/pruitt-was-the-kato-kaelin-of-capitol-hill-505658', 0, 'EPA Chief Scott Pruitt Was An Awful Tenant At His Controversial Washington Condo', 'society', 0, '2018-04-09 05:57:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1405, 1, 'http://digg.com/video/what-causes-body-odor', 0, 'What Is Causing Our Body Odor?', 'body', 0, '2018-04-09 05:59:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1406, 1, 'https://www.washingtonpost.com/world/national-security/trump-tweets-condemnation-of-syria-chemical-attack-criticizing-putin-for-sharing-the-blame/2018/04/08/c9c1c0e5-d063-4133-ae4d-e26496f79fff_story.html?utm_term=.b77addc3c61d', 0, 'Trump tweets condemnation of Syria chemical attack, saying Putin shares the blame', 'worldnhistory', 0, '2018-04-09 15:23:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1407, 1, 'https://slate.com/technology/2018/04/the-last-logan-paul-assessment-you-ever-have-to-read.html', 0, 'The Antic Avatar of Young White Male Entitlement', 'society', 0, '2018-04-09 15:26:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1408, 1, 'https://www.vox.com/world/2016/11/30/13775920/south-korea-president-park-geun-hye-scandal-prison-sentence', 0, 'South Koreas former president is going to prison. The scandal behind it is batshit.', 'worldnhistory', 0, '2018-04-09 15:28:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1409, 1, 'https://thehustle.co/aairpass-american-airlines-250k-lifetime-ticket/', 0, 'The rise and demise of the AAirpass, American Airlines $250k lifetime ticket', 'worldnhistory', 0, '2018-04-09 15:28:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1410, 1, 'https://www.npr.org/sections/thetwo-way/2018/04/09/600360618/backpage-founders-indicted-on-charges-of-facilitating-prostitution', 0, 'Backpage Founders Indicted On Charges Of Facilitating Prostitution', 'society', 0, '2018-04-10 13:04:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1411, 1, 'https://www.nytimes.com/2018/04/09/upshot/the-10-year-baby-window-that-is-the-key-to-the-womens-pay-gap.html', 0, 'The 10-Year Baby Window That Is the Key to the Womenâ€™s Pay Gap', 'society', 0, '2018-04-10 13:13:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1412, 1, 'http://www.tomsitpro.com/articles/information-security-certifications,2-205.html', 0, 'Best Information Security Certifications 2018', 'scintech', 0, '2018-04-11 05:15:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1413, 1, 'https://washingtonmonthly.com/magazine/april-may-june-2018/null-hypothesis/', 0, 'The Libertarian Who Accidentally Helped Make the Case for Regulation', 'worldnhistory', 0, '2018-04-11 12:39:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1414, 1, 'https://www.wsj.com/articles/theranos-lays-off-most-of-its-remaining-workforce-1523382373?mod=rss_Technology', 0, 'Theranos Lays Off Most of Its Remaining Workforce', 'society', 0, '2018-04-11 12:42:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1415, 1, 'https://www.reuters.com/article/us-mideast-crisis-syria-assad-iran/syrias-assad-vows-to-crush-terrorism-after-western-attack-idUSKBN1HL0NG', 0, 'Syrias Assad vows to crush terrorism after Western attack', 'worldnhistory', 0, '2018-04-14 11:03:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1416, 1, 'https://www.reuters.com/article/us-mideast-crisis-syria-assessment/pro-assad-official-says-targeted-bases-were-evacuated-on-russian-warning-idUSKBN1HL07R', 0, 'Pro-Assad official says targeted bases were evacuated on Russian warning', 'worldnhistory', 0, '2018-04-14 11:05:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1417, 1, 'http://nationalpost.com/pmn/news-pmn/trump-us-allied-strikes-aimed-at-syrias-chemical-weapons', 0, 'Trump: US, allied strikes in Syria bring heated response', 'worldnhistory', 0, '2018-04-14 11:07:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1418, 1, 'https://www.wsj.com/articles/russia-iran-denounce-airstrikes-on-close-ally-syria-1523699441', 0, 'Russia, Iran Denounce Airstrikes on Close Ally Syria', 'worldnhistory', 0, '2018-04-14 11:08:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1419, 1, 'http://www.cbc.ca/news/world/chemical-watchdog-ex-spy-poisoned-nerve-agent-russia-opcw-1.4615895', 0, 'Chemical watchdog confirms ex-spy, daughter were poisoned with high purity nerve agent', 'worldnhistory', 0, '2018-04-14 11:09:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1420, 1, 'http://www.cbc.ca/news/canada/montreal/governor-general-considers-honouring-azzeddine-soufiane-for-bravery-during-quebec-city-mosque-attack-1.4618850', 0, 'Governor General considers honouring Azzeddine Soufiane for bravery during Quebec City mosque attack', 'society', 0, '2018-04-14 11:10:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1421, 1, 'http://www.cbc.ca/news/canada/british-columbia/4-men-suspected-in-string-of-sex-assaults-at-surrey-day-spa-chain-1.4619753', 0, '4 men suspected in string of sex assaults at Surrey day spa chain', 'society', 0, '2018-04-14 11:12:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1422, 1, 'http://www.cbc.ca/news/canada/montreal/governor-general-considers-honouring-azzeddine-soufiane-for-bravery-during-quebec-city-mosque-attack-1.4618850', 0, 'Governor General considers honouring Azzeddine Soufiane for bravery during Quebec City mosque attack', 'worldnhistory', 0, '2018-04-14 11:23:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1423, 1, 'http://www.cbc.ca/news/canada/saskatchewan/medical-student-denied-statement-of-need-1.4609500', 0, 'Canadian medical student nearly loses residency over Health Canada red tape', 'worldnhistory', 0, '2018-04-14 11:23:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1424, 1, 'https://thoughtcatalog.com/maya-kachroo-levine/2015/04/17-signs-hes-not-mysterious-hes-actually-just-an-asshole/', 0, '17 Signs Hes Not Mysterious, Hes Actually Just An Asshole', 'sexndating', 0, '2018-04-16 03:34:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1425, 1, 'https://www.atlasobscura.com/articles/french-laundry-wine-stolen', 0, 'How a Gang of Thirsty Thieves Stole Over $500,000 Worth of Wine', 'society', 0, '2018-04-17 15:41:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1426, 1, 'https://www.vice.com/en_us/article/qvxjvq/racists-in-florida-kept-this-man-from-becoming-a-lawyer-for-30-years', 0, 'Racists in Florida Kept This Man From Becoming a Lawyer for 30 Years', 'worldnhistory', 0, '2018-04-18 16:52:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1427, 1, 'https://www.zdnet.com/article/data-firm-leaks-48-million-user-profiles-it-scraped-from-facebook-linkedin-others/', 0, 'Data firm leaks 48 million user profiles it scraped from Facebook, LinkedIn, others', 'worldnhistory', 0, '2018-04-18 16:52:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1428, 2, NULL, 0, 'He who asks a question, is a fool for 5 min; He who doesn\'t ask a question remains a fool forever.', 'worldnhistory', 24, '2018-04-18 19:51:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1429, 1, 'https://qz.com/1255335/paid-time-off-workers-in-the-us-with-the-highest-salaries-also-get-the-most-paid-vacation/', 0, 'The higher your salary, the more time your employer will pay you not to work', 'society', 0, '2018-04-19 07:25:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1430, 1, 'https://www.youtube.com/watch?v=EmSYI6AjFUg', 0, 'The Psychological Quirk That Makes Shitty Artists Think Theyre Great', 'scintech', 0, '2018-04-19 07:26:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1431, 1, 'https://www.geek.com/science/diamonds-found-in-meteorite-tell-story-of-destroyed-planet-1737483/', 0, 'Diamonds found In Meteorite Tell Story of Destroyed Planet', 'scintech', 0, '2018-04-20 12:53:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1432, 1, 'http://www.alphr.com/space/1009138/nasa-big-news-nuclear-power-space-kilopower-announcement', 0, 'Project Kilopower: NASA is about to drop big news on nuclear power in space', 'scintech', 0, '2018-04-20 12:54:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1433, 1, 'https://www.drugtargetreview.com/news/31236/hiv-evades-elimination/', 0, 'Scientists uncover how HIV evades elimination by the immune system', 'scintech', 0, '2018-04-20 12:54:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1434, 1, 'http://www.cbc.ca/news/canada/british-columbia/complaint-filed-against-naturopath-who-gave-boy-remedy-made-from-rabid-dog-saliva-1.4627618', 0, 'Complaint filed against naturopath who gave boy remedy made from rabid-dog saliva', 'scintech', 0, '2018-04-20 12:55:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1435, 1, 'http://www.cbc.ca/news/world/israel-70th-anniversary-1.4626719', 0, 'Israel celebrates 70th anniversary of independent Jewish state', 'worldnhistory', 0, '2018-04-20 12:55:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1436, 1, 'http://www.cbc.ca/news/world/comey-memo-fbi-trump-flynn-1.4627802', 0, 'Trump talks of jailed journalists and hookers in Comey memos', 'worldnhistory', 0, '2018-04-20 12:56:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1437, 1, 'https://www.washingtonpost.com/politics/trump-hires-giuliani-two-other-attorneys-amid-mounting-legal-turmoil-over-russia/2018/04/19/8346a7ca-4418-11e8-8569-26fda6b404c7_story.html?utm_term=.472154238541', 0, 'Trump hires Giuliani, two other attorneys amid mounting legal turmoil over Russia', 'worldnhistory', 0, '2018-04-20 13:27:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1438, 1, 'https://www.nature.com/articles/d41586-018-04600-8', 0, 'Medicines secret ingredient â€”ï»¿ its in the timing', 'body', 0, '2018-04-22 12:23:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1439, 1, 'https://www.bloomberg.com/news/features/2018-04-20/h-1b-workers-are-leaving-trump-s-america-for-the-canadian-dream', 0, 'Engineers Are Leaving Trumps America for the Canadian Dream', 'society', 0, '2018-04-22 13:31:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1440, 1, 'https://www.smithsonianmag.com/science-nature/great-chinese-dino-boom-180968745/', 0, 'The Great Chinese Dinosaur Boom', 'worldnhistory', 0, '2018-04-22 13:32:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1441, 1, 'https://www.atlasobscura.com/articles/dying-banyan-tree-survives-with-iv', 0, 'A Dying 700-Year-Old Banyan Tree Was Brought Back to Life With an IV', 'scintech', 0, '2018-04-23 06:16:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1442, 1, 'https://www.theatlantic.com/science/archive/2018/04/bajau-sea-nomads-diving-evolution-spleen/558359/', 0, 'How Asias Super Divers Evolved for a Life At Sea', 'body', 0, '2018-04-23 06:23:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1443, 1, 'https://www.youtube.com/watch?v=e681QNbHloE', 0, 'How IBM quietly pushed out 20,000 older workers', 'society', 0, '2018-04-23 13:15:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1444, 1, 'http://www.cbc.ca/news/world/waffle-house-gunman-sought-1.4631066', 0, 'Waffle House hero snatched AR-15 from gunman', 'society', 0, '2018-04-23 13:25:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1445, 1, 'https://www.newyorker.com/magazine/2018/04/30/how-american-racism-influenced-hitler?mbid=synd_digg', 0, 'How American Racism Influenced Hitler', 'worldnhistory', 0, '2018-04-24 02:03:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1446, 1, 'https://work.qz.com/1260571/at-work-a-respectful-culture-is-better-than-a-nice-one/', 0, 'The unintended consequences of a too-nice work culture', 'society', 0, '2018-04-25 19:36:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1447, 1, 'http://digg.com/video/daily-selfie-time-lapse', 0, 'Girl Literally Grows Up Before Our Eyes In This Time-Lapse Of Selfies Taken Every Day From Age 14 To 22', 'body', 0, '2018-04-28 01:29:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0);
INSERT INTO `articlelinks` (`linkid`, `linktype`, `link`, `imageid`, `title`, `category`, `articleid`, `createdate`, `revisedate`, `voteup`, `votedown`, `voteinternal`, `creatorid`, `numcomments`) VALUES
(1448, 1, 'http://www.cbc.ca/news/canada/british-columbia/sex-charges-dropped-against-hiv-positive-b-c-man-1.4639752', 0, 'Sex charges stayed against HIV-positive B.C. man', 'sexndating', 0, '2018-04-28 12:36:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1449, 1, 'https://nplusonemag.com/online-only/online-only/were-the-good-guys-right/', 0, 'We&#44re the Good Guys, Right?', 'general', 0, '2018-04-28 12:51:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1450, 1, 'http://digg.com/video/wind-rips-roof-building', 0, 'High Winds Easily Peel The Rooftop Right Off A Building\'\'', 'scintech', 0, '2018-04-28 12:55:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1451, 1, 'http://digg.com/2018/greenest-states-in-america', 0, 'The Greenest States In America, According To Experts\'', 'scintech', 0, '2018-04-28 12:56:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1452, 1, 'https://jezebel.com/saint-elliot-rodger-and-the-incels-who-canonize-him-1825567815', 0, 'Saint Elliot Rodger and the \'Incels\' Who Canonize Him', 'society', 0, '2018-04-28 12:59:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1453, 1, 'https://www.theatlantic.com/education/archive/2018/04/college-admissions-antitrust/559088/?utm_source=feed', 0, 'The Best Ways to Fix College Admissions Are Probably Illegal', 'worldnhistory', 0, '2018-04-28 18:41:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1454, 1, 'https://www.racked.com/2018/4/28/17290256/incel-chad-stacy-becky', 0, 'Incels Categorize Women by Personal Style and Attractiveness', 'society', 0, '2018-04-28 23:25:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1455, 1, 'https://theintercept.com/2018/04/28/computer-malware-tampering/', 0, 'ITâ€™S IMPOSSIBLE TO PROVE YOUR LAPTOP HASNâ€™T BEEN HACKED. I SPENT TWO YEARS FINDING OUT.', 'scintech', 0, '2018-04-29 18:38:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1456, 1, 'https://www.umc.edu/odi/ODI-Initiatives/Unconscious-Bias/Unconscious-Bias-in-Health-Care.html', 0, 'Unconscious Bias in Health Care', 'society', 0, '2018-04-29 19:11:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1457, 1, 'https://www.vice.com/en_us/article/ywx9y5/this-is-what-happens-when-you-eat-nothing-but-bugs-for-a-week', 0, 'This Is What Happens When You Eat Nothing but Bugs for a Week', 'worldnhistory', 0, '2018-05-01 05:11:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1458, 1, 'http://digg.com/video/getting-rid-flies', 0, 'Australian Man Comes Up With Extremely Australian Solution To Stop A Plague Of Flies Attacking His Face', 'scintech', 0, '2018-05-03 01:20:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1459, 1, 'https://melmagazine.com/should-you-warn-someone-about-a-shitty-person-efffb28e4b92', 0, 'Should You Warn Someone About A Shitty Person?', 'society', 0, '2018-05-04 14:17:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1460, 1, 'https://www.newsmax.com/health/health-news/surgeon-skill-improve-age/2018/05/06/id/858621/', 0, 'Surgeons\' Skills Increase With Age: Study', 'society', 0, '2018-05-06 18:09:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1461, 1, 'https://www.castanet.net/news/Canada/225137/A-barrier-to-innovation', 0, ' A barrier to innovation?', 'society', 0, '2018-05-06 18:09:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1462, 1, 'http://www.cbc.ca/news/technology/stephen-hawking-final-paper-1.4648542', 0, 'How to understand Stephen Hawking\'s final paper. Or at least try', 'scintech', 0, '2018-05-06 18:10:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1463, 1, 'https://www.youtube.com/watch?time_continue=158&v=ZwP5GlF0IDM', 0, ' These Chinese Women Only Cut Their Hair Once In Their Lives', 'worldnhistory', 0, '2018-05-07 05:22:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1464, 1, 'https://www.theguardian.com/uk-news/2018/may/05/trump-team-hired-spy-firm-dirty-ops-iran-nuclear-deal', 0, ' Revealed: Trump team hired spy firm for â€˜dirty opsâ€™ on Iran arms deal', 'worldnhistory', 0, '2018-05-07 05:26:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1465, 1, 'https://theintercept.com/2018/05/05/homeless-sex-offenders-florida-miami-dade/', 0, 'Homeless Sex Offenders Are Getting Kicked Out of Their South Florida Encampment. Now What?', 'worldnhistory', 0, '2018-05-07 05:27:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1466, 1, 'https://www.thedailybeast.com/in-death-row-michelle-lyons-recalls-280-executionsand-a-life-marred-by-trauma?via=twitter_page', 0, 'In â€˜Death Row,â€™ Michelle Lyons Recalls 280 Executionsâ€”And a Life Marred by Trauma', 'worldnhistory', 0, '2018-05-07 05:30:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1467, 1, 'https://www.wired.com/story/elon-musks-ire-reveals-a-wall-street-silicon-valley-divide/?mbid=synd_digg', 0, 'Elon Musk\'s Ire Reveals a Wall Street-Silicon Valley Divide', 'scintech', 0, '2018-05-07 05:35:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1468, 1, 'https://www.investopedia.com/partner/reuters/trump-pulls-us-iran-nuclear-deal-revive-sanctions/?utm_source=market-sum&utm_campaign=www.investopedia.com&utm_term=13150062&utm_content=05/08/2018&utm_medium=email', 0, ' Trump Pulls U.S. From Iran Nuclear Deal, to Revive Sanctions', 'worldnhistory', 0, '2018-05-08 21:08:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1469, 1, 'https://www.youtube.com/watch?time_continue=21&v=xfVwr2F26mQ', 0, 'Confessions Of A Japanese Ex-Porn Star | ASIAN BOSS', 'worldnhistory', 0, '2018-05-08 21:30:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1470, 1, 'http://www.cbc.ca/news/canada/calgary/drop-in-mental-health-centre-opens-in-calgary-1.4654309', 0, 'Mental health \'recovery college centre opens in downtown Calgary', 'society', 0, '2018-05-09 03:21:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1471, 1, 'https://fightthenewdrug.org/porn-stats-which-country-hosts-most-porn/', 0, 'Porn Stats: Which Country Produces And Hosts The Most Porn?', 'society', 0, '2018-05-09 11:17:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1472, 1, 'http://www.bbc.com/news/technology-23030090', 0, 'Web porn: Just how much is there?', 'society', 0, '2018-05-09 11:18:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1473, 1, 'https://www.cp24.com/news/a-look-at-bruce-mcarthur-s-alleged-victims-1.3880979', 0, 'A look at Bruce McArthur\'s alleged victims', 'society', 0, '2018-05-09 11:28:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1474, 1, 'https://www.ctvnews.ca/politics/canada-to-apologize-for-turning-away-ship-of-jewish-refugees-fleeing-nazis-1.3921334', 0, ' Canada to apologize for turning away ship of Jewish refugees fleeing Nazis', 'worldnhistory', 0, '2018-05-09 14:42:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1475, 1, 'https://www.nature.com/articles/d41586-018-05118-9', 0, 'Radar reveals North Koreaâ€™s nuclear test moved a mountain', 'worldnhistory', 0, '2018-05-13 15:42:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1476, 1, 'http://digg.com/video/is-our-world-a-simulation', 0, 'Is It Possible That Our World Is Just A Simulation?', 'scintech', 0, '2018-05-14 13:05:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1477, 1, 'https://arstechnica.com/science/2018/05/genghis-khans-mongol-horde-probably-had-rampant-hepatitis-b/?mbid=synd_digg', 0, 'Genghis Khanâ€™s Mongol horde probably had rampant Hepatitis B', 'worldnhistory', 0, '2018-05-14 13:11:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1478, 1, 'http://digg.com/video/why-argue-kids', 0, 'Maybe It\'s Good To Have Disagreements In Front Of Your Kids?', 'society', 0, '2018-05-14 13:13:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1479, 1, 'https://www.youtube.com/watch?time_continue=138&v=7uCoMglUDKI', 0, 'Why You Should Argue in Front of Your Kids', 'society', 0, '2018-05-14 13:16:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1480, 1, 'http://digg.com/video/why-sociable-people-hate-parties', 0, 'Why Truly Sociable People Are Horrified By Parties', 'society', 0, '2018-05-14 13:16:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1481, 1, 'https://www.washingtonpost.com/lifestyle/gossip-explains-our-culture-and-nobody-explains-it-like-lainey-gossip/2018/05/10/819e33f2-52c3-11e8-abd8-265bd07a9859_story.html?noredirect=on&utm_term=.2e37a1959276', 0, 'Gossip explains our culture. And nobody explains it like Lainey Gossip.', 'society', 0, '2018-05-14 16:48:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1482, 1, 'https://www.vice.com/en_us/article/435g9p/how-to-help-an-incel-sex-therapist', 0, 'This Is What It\'s Like to Treat an Incel as a Sex Therapist', 'society', 0, '2018-05-14 18:48:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1483, 1, 'https://arstechnica.com/tech-policy/2018/05/jails-are-replacing-in-person-visits-with-video-calling-services-theyre-awful/?mbid=synd_digg', 0, 'Jails are replacing visits with video callsâ€”inmates and families hate it', 'society', 0, '2018-05-14 22:39:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1484, 1, 'https://www.wired.com/story/efail-encrypted-email-flaw-pgp-smime/?mbid=synd_digg', 0, 'ENCRYPTED EMAIL HAS A MAJOR, DIVISIVE FLAW', 'scintech', 0, '2018-05-15 00:46:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1485, 1, 'https://www.cnbc.com/2016/07/26/the-25-highest-paying-jobs-in-america.html', 0, 'The 25 highest-paying jobs in America', 'society', 0, '2018-05-15 09:06:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1486, 1, 'https://www.nature.com/articles/d41586-018-05109-w', 0, 'Why itâ€™s hard to prove gender discrimination in science', 'society', 0, '2018-05-16 06:55:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1487, 1, 'https://www.nature.com/articles/d41586-018-05139-4', 0, 'ï»¿Sacked Japanese biologist gets chance to retrain at Crick institute', 'society', 0, '2018-05-16 06:56:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1488, 1, 'https://www.theatlantic.com/technology/archive/2018/05/tiziana-cantone-suicide-right-to-be-forgotten/559289/?utm_source=feed', 0, 'A Mother Wants the Internet to Forget Italy\'s Most Viral Sex Tape', 'society', 0, '2018-05-16 19:09:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1489, 1, 'https://motherboard.vice.com/en_us/article/gykgv9/securus-phone-tracking-company-hacked', 0, 'Hacker Breaches Securus, the Company That Helps Cops Track Phones Across the US', 'scintech', 0, '2018-05-17 09:23:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1490, 1, 'http://digg.com/2018/net-neutrality-what-s-next', 0, 'The Senate Just Voted To Stop The Repeal Of Net Neutrality â€” Here\'s What Happens Next', 'worldnhistory', 0, '2018-05-17 09:24:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1491, 1, 'https://www.gq.com/story/maintenance-texts?mbid=synd_digg', 0, 'How to Keep Your Relationship Alive with One Text a Day', 'society', 0, '2018-05-17 09:26:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1492, 1, 'https://www.nature.com/articles/d41586-018-05143-8', 0, 'Some hard numbers on scienceâ€™s leadership problems', 'society', 0, '2018-05-17 18:53:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1493, 1, 'http://www.thisisinsider.com/narcissistic-personality-disorder-signs-2018-4?utm_source=quora&utm_medium=referral', 0, '7 signs you\'re dating a narcissist, according to a clinical psychologist', 'sexndating', 0, '2018-05-18 14:32:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1494, 1, 'http://digg.com/video/new-york-lawyer-spanish-call-ice', 0, 'Manhattan Lawyer Hears Women Speaking Spanish In Restaurant, Threatens To Call ICE On Them', 'society', 0, '2018-05-18 19:06:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1495, 1, 'https://www.nature.com/articles/d41586-018-05205-x', 0, 'Experimental drugs poised for use in Ebola outbreak', 'scintech', 0, '2018-05-18 19:08:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1496, 1, 'https://www.youtube.com/watch?time_continue=161&v=wJdNrCeUdhc', 0, 'Can You Name a Book? ANY Book???', 'society', 0, '2018-05-19 03:08:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1497, 1, 'http://www.bbc.com/travel/story/20180517-the-island-fruit-that-caused-a-mutiny', 0, 'Breadfruit', 'general', 0, '2018-05-19 04:40:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1498, 1, 'http://digg.com/2018/boomers-ruined-america', 0, 'Boomers Are Going To Get Away With Screwing America, And Other Facts', 'worldnhistory', 0, '2018-05-19 04:40:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1499, 1, 'http://money.cnn.com/2018/05/17/news/economy/us-middle-class-basics-study/', 0, 'Almost half of US families can\'t afford basics like rent and food', 'society', 0, '2018-05-19 04:48:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1500, 1, 'https://www.psychologytoday.com/us/blog/wicked-deeds/201406/serial-killer-myth-1-theyre-mentally-ill-or-evil-geniuses', 0, 'Serial Killer Myth #1: They\'re Mentally Ill or Evil Geniuses', 'society', 0, '2018-05-19 23:16:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1501, 1, 'https://www.theglobeandmail.com/news/national/wont-greet-karla-homolka-family-says/article18228794/', 0, 'Won\'t greet Karla, Homolka family says', 'society', 0, '2018-05-20 16:23:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1502, 1, 'https://www.youtube.com/watch?v=Ziqq5gUXu8g', 0, 'I Survived North Korea', 'worldnhistory', 0, '2018-05-20 17:56:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1503, 1, 'https://www.youtube.com/watch?v=PdxPCeWw75k', 0, 'My escape from North Korea | Hyeonseo Lee', 'worldnhistory', 0, '2018-05-20 23:52:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1504, 1, 'http://www.cbc.ca/news/canada/toronto/sexual-assault-claims-dominican-republic-resort-1.4665672', 0, '\'I could have ID\'d him\': Woman says Dominican resort didn\'t investigate claim that she was raped by staffer', 'worldnhistory', 0, '2018-05-21 12:35:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1505, 1, 'http://torontosun.com/news/national/the-serial-killers-who-terrorized-canadians', 0, 'The serial killers who terrorized Canadians', 'society', 0, '2018-05-22 14:34:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1506, 1, 'https://www.nature.com/articles/d41586-018-05242-6', 0, 'Why North Korea\'s denuclearization plan doesn\'t convince this nuclear expert', 'worldnhistory', 0, '2018-05-23 17:26:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1507, 1, 'https://www.vox.com/2018/5/23/17353284/emergency-room-doctor-out-of-network', 0, 'He went to an in-network emergency room. He still ended up with a $7,924 bill.', 'society', 0, '2018-05-24 02:54:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1508, 1, 'https://www.nature.com/articles/d41586-018-05249-z', 0, 'Listen: How maths could drastically shrink New Yorkâ€™s cab fleet', 'scintech', 0, '2018-05-24 12:27:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1509, 1, 'https://www.insauga.com/mississauga-man-charged-in-toronto-sex-assault', 0, 'Mississauga Man Charged in Toronto Sex Assault', 'society', 0, '2018-05-24 12:37:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1510, 1, 'https://www.cnn.com/2018/05/24/entertainment/morgan-freeman-accusations/index.html', 0, 'Women accuse Morgan Freeman of inappropriate behavior, harassment', 'society', 0, '2018-05-24 22:04:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1511, 1, 'https://www.smithsonianmag.com/innovation/why-are-finlands-schools-successful-49859555/', 0, 'Why Are Finlandâ€™s Schools Successful?', 'worldnhistory', 0, '2018-05-26 05:50:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1512, 1, 'https://www.hhs.gov/answers/mental-health-and-substance-abuse/what-does-suicide-contagion-mean/index.html', 0, 'What does \'suicide contagion\' mean, and what can be done to prevent it?', 'society', 0, '2018-05-28 13:41:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1513, 1, 'https://www.youtube.com/watch?v=SLxBCSSgJ0s', 0, 'Two Toronto Officers Charged After Allegedly Taking Edibles On Duty', 'society', 0, '2018-05-28 14:00:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1514, 1, 'https://toronto.ctvnews.ca/video?clipId=960678', 0, 'Caught on cam: Renters asked to pay with sex | CTV Toronto News', 'society', 0, '2018-05-28 14:24:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1515, 1, 'https://www.theverge.com/2018/5/28/17401892/intel-age-discrimination-layoffs-investigation', 0, 'Intel accused of age discrimination', 'society', 0, '2018-05-28 16:37:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1516, 1, 'http://web.mit.edu/mprat/Public/web/Terminus/Web/main.html', 0, 'Terminus', 'scintech', 0, '2018-06-04 22:01:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1517, 1, 'https://seed-balls.com/what-are-seed-balls', 0, 'What are Seed Balls?', 'scintech', 0, '2018-06-06 13:17:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1518, 1, 'https://en.wikipedia.org/wiki/Compulsory_sterilization_in_Canada', 0, 'Compulsory sterilization in Canada', 'worldnhistory', 0, '2018-06-06 13:48:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1519, 1, 'https://www.nature.com/articles/d41586-018-05383-8', 0, 'North Korean disarmament: build technology and trust', 'worldnhistory', 0, '2018-06-09 03:28:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1520, 1, 'https://www.nature.com/articles/d41586-018-05359-8', 0, 'China introduces sweeping reforms to crack down on academic misconduct', 'scintech', 0, '2018-06-09 16:05:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1521, 1, 'https://dzone.com/articles/how-to-overcome-it-employee-retention-challenge-wi', 0, 'How to Overcome IT Employee Retention Challenge With No Harm To Your Organization', 'scintech', 0, '2018-06-09 19:34:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1522, 1, 'https://www.nature.com/articles/d41586-018-05404-6', 0, 'Sexual harassment is rife in the sciences, finds landmark US study', 'society', 0, '2018-06-14 12:42:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1523, 1, 'https://www.bbc.com/news/science-environment-44472277', 0, 'Einstein\'s travel diaries reveal racist stereotypes', 'society', 0, '2018-06-14 13:02:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1524, 1, 'https://www.thecut.com/article/intermittent-fasting.html', 0, 'The Ultimate Guide to Intermittent Fasting', 'body', 0, '2018-06-17 14:30:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1525, 1, 'https://gizmodo.com/these-tests-will-tell-you-just-how-good-your-eyes-are-a-1826868420', 0, 'These Tests Will Tell You Just How Good Your Eyes Are at Seeing Color', 'body', 0, '2018-06-17 14:44:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1526, 1, 'http://www.bbc.com/future/story/20180613-why-stressed-minds-are-better-at-processing-things', 0, 'Stressed minds are better at making decisions', 'body', 0, '2018-06-17 14:45:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1527, 1, 'https://www.cnbc.com/2018/06/18/elon-musk-email-employee-conducted-extensive-and-damaging-sabotage.html', 0, 'Elon Musk emails employees about \'extensive and damaging sabotage\' by employee', 'society', 0, '2018-06-20 12:18:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1528, 1, 'https://abcnews.go.com/Politics/us-withdraws-human-rights-council/story?id=56009661', 0, 'US withdraws from UN Human Rights Council', 'worldnhistory', 0, '2018-06-20 12:51:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1529, 1, 'https://fivethirtyeight.com/features/what-do-men-think-it-means-to-be-a-man/', 0, 'What Do Men Think It Means To Be A Man?', 'society', 0, '2018-06-20 20:08:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1530, 1, 'https://www.revealnews.org/article/migrant-children-sent-to-shelters-with-histories-of-abuse-allegations/', 0, 'Migrant children sent to shelters with histories of abuse allegations', 'society', 0, '2018-06-20 20:09:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1531, 1, 'https://www.youtube.com/watch?time_continue=5&v=tlB1pFwGhA4', 0, 'Bullying and Corporate Psychopaths at Work: Clive Boddy', 'society', 0, '2018-06-21 14:39:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1532, 1, 'https://www.youtube.com/watch?v=20DPgRoyQn0', 0, 'Build Mini Underground Swimming Pool', 'scintech', 0, '2018-06-22 17:17:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1533, 1, 'https://www.youtube.com/watch?v=mn1DEeyqaT4', 0, 'Build Swimming Pool Around Underground House', 'scintech', 0, '2018-06-22 17:22:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1534, 1, 'http://mentalfloss.com/article/548757/authorities-crack-joseph-newton-chandler-mystery-zodiac-killer', 0, 'Authorities Have Cracked a Bizarre Cold Case That Could Have Ties to the Zodiac Killer', 'worldnhistory', 0, '2018-06-22 17:24:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1535, 1, 'https://www.youtube.com/watch?v=Foe4aM7wVKg', 0, 'Catch Water duck by hand in forest - Catch N Cook', 'scintech', 0, '2018-06-22 17:54:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1536, 1, 'https://www.youtube.com/watch?v=e0Rt4VdTgus', 0, 'Find honeybee for lunch in the forest', 'scintech', 0, '2018-06-22 17:59:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1537, 1, 'https://www.youtube.com/watch?v=iFGfHxV_zsw', 0, 'Make Tool To Take Water From Groundwater', 'scintech', 0, '2018-06-22 18:08:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1538, 1, 'https://www.youtube.com/watch?v=J3XwxtsR-zs', 0, 'The Differences Between Japanese Jiu-Jitsu and Brazilian Jiu-Jitsu ã€JJJ Â¬ BJJã€‘æŸ”è¡“ | æŸ”é“', 'body', 0, '2018-06-22 18:39:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1539, 1, 'https://www.vox.com/science-and-health/2017/12/14/16687388/cruelty-border-immigration-psychology-human-nature', 0, 'Why humans are cruel', 'society', 0, '2018-06-23 07:27:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1540, 1, 'http://www.muaythaischolar.com/muay-thai-fight-in-thailand/', 0, 'How Much Will I Get Paid For a Fight in Thailand?', 'worldnhistory', 0, '2018-06-23 15:23:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1541, 1, 'http://www.muaythaischolar.com/20-ways-to-save-money-in-thailand/', 0, '20 Ways To Save Money in Thailand', 'worldnhistory', 0, '2018-06-23 16:33:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1542, 1, 'https://www.youtube.com/watch?v=GpdCo2L809U', 0, '\'We Bring The Fight\' - Dutch Kickboxing Documentary', 'general', 0, '2018-06-23 17:09:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1543, 1, 'https://www.youtube.com/watch?v=D9L5vr3HKdE', 0, 'UFC Joe Rogan says that Wing Chun Kung Fu is ineffective and a waste of time!', 'scintech', 0, '2018-06-24 05:39:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1544, 1, 'https://www.nytimes.com/2018/06/22/science/tree-dna-database.html', 0, 'Can a DNA Database Save the Trees? These Scientists Hope So', 'scintech', 0, '2018-06-24 16:36:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1545, 1, 'https://theblog.okcupid.com/undressed-this-is-what-dating-culture-looks-like-across-the-us-ef46e8429b0a', 0, 'Undressed: This is what dating culture looks like across the US', 'worldnhistory', 0, '2018-06-24 17:27:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1546, 1, 'https://www.npr.org/2018/01/09/575352051/least-desirable-how-racial-discrimination-plays-out-in-online-dating', 0, '\'Least Desirable\'? How Racial Discrimination Plays Out In Online Dating', 'sexndating', 0, '2018-06-24 18:18:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1547, 1, 'https://www.politico.com/magazine/story/2018/06/23/washington-dc-the-psychopath-capital-of-america-218892', 0, 'Washington, D.C.: the Psychopath Capital of America', 'worldnhistory', 0, '2018-06-24 20:03:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1548, 1, 'https://thoughtcatalog.com/elan-morgan/2017/03/three-ridiculous-things-that-got-me-fired-in-less-than-one-day/', 0, 'Three Ridiculous Things That Got Me Fired In Less Than One Day', 'society', 0, '2018-06-24 20:11:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1549, 1, 'https://slate.com/human-interest/2018/03/dear-prudence-help-my-co-worker-is-trying-to-undermine-me.html', 0, 'Help! A Nasty Co-Worker Is Trying to Get Me Fired.', 'society', 0, '2018-06-24 20:13:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1550, 1, 'https://www.psychologytoday.com/ca/blog/head-games/201709/growing-mentally-ill-parent-6-core-experiences', 0, 'Growing Up With a Mentally Ill Parent: 6 Core Experiences', 'society', 0, '2018-06-24 20:15:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1551, 1, 'http://www.myfightcamp.com/2011/06/actual-monthly-living-costs-training.html', 0, 'Actual Monthly Living Costs - Training MMA and Muay Thai in Thailand', 'worldnhistory', 0, '2018-06-25 15:13:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1552, 1, 'http://www.myfightcamp.com/2011/05/chiang-mai-muay-thai-camps-lanna-santai.html', 0, 'Chiang Mai Muay Thai Camps - Lanna, Santai, and Chay Yai Gym', 'worldnhistory', 0, '2018-06-25 15:28:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1553, 1, 'https://southeastasiabackpacker.com/activities/muay-thai-boxing/', 0, 'Where are the best places to learn Muay Thai?', 'worldnhistory', 0, '2018-06-25 15:53:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1554, 1, 'http://tqmmathailand.com/prices/', 0, 'Team Quest Thailand', 'worldnhistory', 0, '2018-06-25 16:21:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1555, 1, 'http://forums.sherdog.com/threads/getting-a-fight-in-thailand.2070077/', 0, 'Getting a Fight In Thailand', 'worldnhistory', 0, '2018-06-26 17:35:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1556, 1, 'http://www.muaythaiathlete.com/5-reasons-why-you-should-fight-in-thailand/', 0, '5 Reasons You Should Fight In Thailand', 'worldnhistory', 0, '2018-06-26 17:38:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1557, 1, 'https://www.nature.com/articles/d41586-018-05561-8', 0, 'Top US court upholds Trump travel ban: student visas already in decline', 'worldnhistory', 0, '2018-06-27 12:54:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1558, 1, 'https://www.theguardian.com/news/2018/jun/28/how-to-get-away-with-financial-fraud', 0, 'How to get away with financial fraud', 'society', 0, '2018-06-28 15:27:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1559, 1, 'http://digg.com/2018/highest-paid-athletes-salaries', 0, 'How Much Money The World\'s Highest-Paid Athletes Earn, Charted', 'society', 0, '2018-06-28 15:29:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1560, 1, 'http://www.baltimoresun.com/news/maryland/crime/bs-md-gazette-shooting-20180628-story.html', 0, 'Five dead, others \'gravely injured\' in shooting at Capital Gazette newspaper in Annapolis', 'society', 0, '2018-06-28 23:32:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1561, 1, 'http://www.chiangmaicitylife.com/citylife-articles/being-black-in-thailand/', 0, 'Being Black in Thailand', 'worldnhistory', 0, '2018-06-30 03:16:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1562, 1, 'https://ca.news.yahoo.com/canada-launching-retaliatory-tariff-broadside-183545095.html', 0, 'American goods that will take the tariff hit', 'worldnhistory', 0, '2018-06-30 14:01:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1563, 1, 'https://ca.news.yahoo.com/alberta-family-physician-charged-child-181258834.html', 0, 'Alberta family physician charged with child exploitation', 'society', 0, '2018-06-30 14:01:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1564, 1, 'https://qz.com/1318203/making-pennies-costs-the-us-mint-millions/', 0, 'The US Mint lost $69 million making pennies last year', 'worldnhistory', 0, '2018-07-01 12:58:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1565, 1, 'https://longreads.com/2018/06/29/pay-the-homeless/', 0, 'Pay the Homeless', 'society', 0, '2018-07-01 14:20:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1566, 1, 'http://www.cracked.com/article_20033_5-ridiculous-assassination-plots-that-actually-worked.html', 0, '5 Ridiculous Assassination Plots That Actually Worked', 'worldnhistory', 0, '2018-07-02 20:09:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1567, 1, 'https://www.nature.com/articles/d41586-018-05587-y', 0, 'LGBTQ scientists are still left out', 'society', 0, '2018-07-03 18:35:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1568, 1, 'https://hazlitt.net/feature/personal-business-being-laid', 0, 'The Personal Business of Being Laid Off', 'society', 0, '2018-07-11 07:55:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1569, 1, 'https://www.geekandjock.com/10-survival-tips-for-your-first-date-with-a-thai-woman', 0, 'How To Survive a Thai Woman On the 1st Date :)', 'society', 0, '2018-07-14 21:31:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1570, 1, 'https://www.heycrush.com/blog/win-thai-womans-heart/', 0, 'How to Win a Thai Womanâ€™s Heart', 'society', 0, '2018-07-14 21:35:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1571, 1, 'https://www.wikihow.com/Romance-a-Girl', 0, 'Romance a Girl', 'sexndating', 0, '2018-07-14 22:24:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1572, 1, 'https://melmagazine.com/the-gentlemans-guide-to-confronting-the-fuck-up-in-your-friend-group-577d1866b94f', 0, 'The Gentlemanâ€™s Guide to Confronting the Fuck-Up in Your Friend Group', 'society', 0, '2018-07-15 03:06:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1573, 1, 'http://digg.com/video/dog-panic-attack', 0, 'Assistance Dog Can Sense His Owner\'s Emotions, Keeps Her From Having A Full Blown Panic Attack', 'society', 0, '2018-07-15 03:08:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1574, 1, 'https://www.yourtango.com/experts/hayley-matthews/5-ways-deal-when-someone-comes-between-your-relationship', 0, '5 Clever Ways To Deal With The JERK Trying To Ruin Your Relationship', 'sexndating', 0, '2018-07-18 11:51:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1575, 1, 'https://youqueen.com/love/relationships/how-not-to-let-others-ruin-your-relationship/', 0, 'HOW NOT TO LET OTHERS RUIN YOUR RELATIONSHIP', 'sexndating', 0, '2018-07-18 11:52:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1576, 1, 'http://digg.com/2018/iphone-x-index-world-visualized', 0, 'How Many Hours You Need To Work To Buy A New iPhone In Different Parts Of The World, Visualized', 'worldnhistory', 0, '2018-07-19 09:51:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1577, 1, 'https://www.bloomberg.com/news/features/2018-07-18/japan-s-lonely-death-industry', 0, 'Dying Alone in Japan: The Industry Devoted to Whatâ€™s Left Behind', 'worldnhistory', 0, '2018-07-19 10:02:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1578, 1, 'https://www.vox.com/2018/7/18/17561266/summer-2018-heat-wave-weather-health', 0, 'The disturbing reason heat waves can kill people in cooler climates', 'scintech', 0, '2018-07-19 10:03:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1579, 1, 'https://medium.com/s/futurehuman/how-facial-recognition-tech-could-tear-us-apart-c4486c1ee9c4', 0, 'How Facial Recognition Could Tear Us Apart', 'scintech', 0, '2018-07-19 10:34:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1580, 1, 'https://www.theguardian.com/film/2010/oct/17/crime-introduction', 0, 'The 25 best crime films of all time ', 'cinema', 0, '2018-07-23 04:52:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1581, 1, 'https://www.bankerinthesun.com/2014/12/bad-terrible-thai-dating-experience/', 0, 'My Terrible Thai Dating Experience', 'worldnhistory', 0, '2018-07-24 15:03:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1582, 1, 'https://www.bankerinthesun.com/2014/10/how-to-find-a-good-girl-in-thailand/', 0, 'How To Find A Good Girl in Thailand', 'society', 0, '2018-07-24 15:25:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1583, 1, 'https://www.themasculinetraveler.com/thai-women-12-lessons/', 0, '12 Lessons I Learned from Falling in Love with a Thai Woman â€“ Overview', 'sexndating', 0, '2018-07-24 20:25:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1584, 1, 'https://www.thethailandlife.com/uk-visitor-visa-thai-partner', 0, 'How to Get a UK Visitor Visa for Your Thai Partner [in 7 Steps]', 'worldnhistory', 0, '2018-07-24 20:53:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1585, 1, 'https://www.vox.com/first-person/2018/7/24/17603616/depression-treatment-severe-ketamine-special-k', 0, 'I tried ketamine to treat my depression. Within a day, I felt relief.', 'scintech', 0, '2018-07-25 06:31:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1586, 1, 'https://www.huckmag.com/art-and-culture/photography-2/what-is-life-really-like-in-europes-valley-of-terror/', 0, 'What is life really like in Europes Valley of Terror?', 'worldnhistory', 0, '2018-07-25 07:56:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1587, 1, 'https://www.thecut.com/2018/07/the-kinds-of-monsters-i-used-to-date.html', 0, 'Monsters I Used to Date: Itâ€™s hardest to contend with men whose main focus is to not seem like a monster.', 'general', 0, '2018-07-25 11:52:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1588, 1, 'https://www.newyorker.com/culture/cultural-comment/refinery29-kylie-jenner-and-the-denial-underlying-millennial-financial-resentment?mbid=synd_digg', 0, 'the Denial Underlying Millennial Financial Resentment', 'society', 0, '2018-07-25 11:54:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1589, 1, 'https://qz.com/1334148/this-3d-holographic-display-is-actually-affordable/', 0, 'Your next computer screen could be holographic', 'scintech', 0, '2018-07-25 11:59:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1590, 1, 'https://www.lovepanky.com/love-couch/romantic-love/16-non-sexual-touches-to-feel-connected-and-loved', 0, '16 Non-Sexual Touches to Feel Connected and Loved', 'sexndating', 0, '2018-07-25 17:37:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1591, 1, 'https://www.lovepanky.com/men/attracting-and-dating-women/does-she-like-me', 0, 'Does She Like Me? 17 Signs Sheâ€™s Clearly Interested in You', 'sexndating', 0, '2018-07-26 03:25:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1592, 1, 'https://pairedlife.com/dating/If-A-Girl-Likes-You', 0, '26 Ways to Tell If a Girl Likes You', 'sexndating', 0, '2018-07-26 03:29:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1593, 1, 'https://www.luvze.com/female-body-language-signs-she-likes-you/', 0, '44 Female Body Language Signs She Likes You', 'sexndating', 0, '2018-07-26 03:37:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1594, 1, 'https://www.wikihow.com/Get-a-Girl-to-Fall-in-Love-with-You', 0, 'How to Get a Girl to Fall in Love with You', 'sexndating', 0, '2018-07-26 04:27:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1595, 1, 'https://www.npr.org/2018/07/26/632724239/facial-recognition-software-wrongly-identifies-28-lawmakers-as-crime-suspects', 0, 'Facial Recognition Software Wrongly Identifies 28 Lawmakers As Crime Suspects', 'scintech', 0, '2018-07-27 01:15:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1596, 1, 'http://digg.com/2018/college-degrees-highest-salaries-visualized', 0, 'Which College Degrees Earn The Highest Salaries, Charted', 'society', 0, '2018-07-27 01:16:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1597, 1, 'https://www.techdirt.com/articles/20180716/12572540243/hacked-passwords-being-used-blackmail-attempt-expect-more-this.shtml', 0, 'Hacked Passwords Being Used In Blackmail Attempt -- Expect More Of This', 'scintech', 0, '2018-07-27 02:26:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1598, 1, 'https://hackspirit.com/fat-man-learned-shocking-lesson-women-losing-weight/', 0, 'This overweight man learned a surprising lesson about women after losing weight', 'sexndating', 0, '2018-07-27 16:51:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1599, 1, 'http://www.bbc.com/capital/story/20180727-why-so-many-people-fall-for-scams', 0, 'Why so many people fall for scams', 'society', 0, '2018-07-27 23:04:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1600, 1, 'https://www.lovepanky.com/love-couch/better-love/reasons-your-relationship-is-at-a-standstill', 0, '10 Reasons Your Relationship is at a Standstill', 'sexndating', 0, '2018-07-27 23:25:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1601, 1, 'https://www.wired.co.uk/article/water-on-mars-lake', 0, 'We\'ve found a lake of water on Mars. So what happens next?', 'scintech', 0, '2018-07-27 23:26:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1602, 1, 'https://qz.com/1340252/even-tech-workers-think-theyre-underpaid/', 0, 'Even tech workers think theyâ€™re underpaid', 'society', 0, '2018-07-27 23:26:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1603, 1, 'https://www.atlasobscura.com/articles/the-other-angkor-wat', 0, 'How Bad Karma and Bad Engineering Doomed an Ancient Cambodian Capital', 'worldnhistory', 0, '2018-07-29 09:12:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1604, 1, 'https://www.newyorker.com/magazine/2018/08/06/les-moonves-and-cbs-face-allegations-of-sexual-misconduct?mbid=synd_digg', 0, 'Les Moonves and CBS Face Allegations of Sexual Misconduct', 'society', 0, '2018-07-29 10:05:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1605, 1, 'https://www.buzzfeednews.com/article/jsherman/gay-men-mutual-masturbation-jack-off-groups', 0, 'Why Some Guys Like Jerking Off Together', 'sexndating', 0, '2018-07-30 00:41:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1606, 1, 'http://nautil.us/blog/-what-if-only-females-could-see-color', 0, 'What If Only Females Could See Color?', 'society', 0, '2018-07-30 00:42:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1607, 1, 'http://www.bbc.com/travel/story/20180729-why-brazilians-are-always-late', 0, 'Why Brazilians Are Always Late', 'worldnhistory', 0, '2018-07-31 00:15:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1608, 1, 'https://www.bangkokpost.com/news/investigation/334017/ladyboys-lost-in-legal-system', 0, 'Transgenders have found unexpected liberation and acceptance in prisons   Please credit and share this article', 'society', 0, '2018-07-31 15:20:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1609, 1, 'https://www.youtube.com/watch?time_continue=230&v=GPhEgtChaag', 0, 'The Story of Japan and Blood Types', 'body', 0, '2018-08-02 07:56:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1610, 1, 'https://www.gq.com/story/how-to-follow-up-after-a-good-first-date?mbid=synd_digg', 0, 'How to Follow Up After a Good First Date', 'sexndating', 0, '2018-08-06 00:31:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1611, 1, 'https://www.nytimes.com/interactive/2018/08/04/upshot/up-birth-age-gap.html?rref=collection%2Fsectioncollection%2Fupshot&action=click&contentCollection=upshot&region=rank&module=package&version=highlights&contentPlacement=1&pgtype=sectionfront', 0, 'The Age That Women Have Babies: How a Gap Divides America', 'society', 0, '2018-08-06 00:44:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1612, 1, 'https://www.nytimes.com/interactive/2018/08/04/upshot/up-birth-age-gap.html?rref=collection%2Fsectioncollection%2Fupshot&action=click&contentCollection=upshot&region=rank&module=package&version=highlights&contentPlacement=1&pgtype=sectionfront', 0, 'The Age That Women Have Babies: How a Gap Divides America', 'society', 0, '2018-08-06 00:44:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1613, 1, 'https://www.theatlantic.com/magazine/archive/2018/09/cognitive-bias/565775/', 0, 'The Cognitive Biases Tricking Your Brain', 'body', 0, '2018-08-06 01:55:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1614, 1, 'https://ca.yahoo.com/news/angelina-jolie-claims-brad-pitt-hasnt-paid-child-support-plans-seek-court-order-192104577.html', 0, 'Angelina Jolie claims Brad Pitt hasn\'t paid child support, plans to seek court order', 'cinema', 0, '2018-08-08 03:52:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1615, 1, 'https://www.elitedaily.com/dating/5-signs-the-person-you-are-dating-actually-likes-you/644497', 0, '5 Signs The Person You Are Dating Actually Likes You', 'sexndating', 0, '2018-08-08 05:37:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1616, 1, 'https://www.psychologytoday.com/us/blog/living-single/201706/why-do-people-lie-you', 0, 'Why Do People Lie to You?', 'society', 0, '2018-08-11 13:26:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1617, 1, 'https://www.eharmony.com/blog/when-dating-how-long-do-you-wait-for-the-ring/#.W27yPdJKjIU', 0, 'When dating, how long do you wait for the ring?', 'sexndating', 0, '2018-08-11 13:28:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1618, 1, 'https://www.polygon.com/2018/8/11/17675738/ninja-twitch-female-gamers', 0, 'Ninja explains his choice not to stream with female gamers', 'society', 0, '2018-08-12 12:25:39', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1619, 1, 'https://www.youtube.com/watch?time_continue=78&v=SFAnrNZ4pD0', 0, 'Is the Dinosaur - Apocalypse Story Wrong?', 'scintech', 0, '2018-08-13 07:52:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1620, 1, 'https://www.lovepanky.com/my-life/relationships/signs-youre-already-smothering-your-partner', 0, '5 Signs Youâ€™re Already Smothering Your Partner', 'sexndating', 0, '2018-08-13 08:59:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1621, 1, 'http://digg.com/video/toddler-puppies', 0, 'This Toddler Being Harassed By A Pack Of Puppies Might Be The Best Thing You Watch Today', 'society', 0, '2018-08-13 17:02:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1622, 1, 'https://www.thecut.com/2018/08/what-to-do-when-you-hate-your-friends-significant-other.html', 0, 'What to Do When You Canâ€™t Stand Your Friendâ€™s Significant Other', 'sexndating', 0, '2018-08-14 16:55:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1623, 1, 'http://digg.com/video/toddler-pool-shove', 0, 'This Toddler Is Absolutely Ruthless', 'society', 0, '2018-08-15 02:09:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1624, 1, 'https://hightimes.com/news/get-the-right-strain-of-weed-to-lose-weight/', 0, 'Get the Right Strain of Weed to Lose Weight', 'scintech', 0, '2018-08-15 09:45:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1625, 1, 'http://attractioninstitute.com/dealing-with-her-male-friends/', 0, 'Dealing With Her Male \'Friends\'', 'sexndating', 0, '2018-08-15 09:47:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1626, 1, 'https://www.lovepanky.com/flirting-flings/dating-game/too-good-to-be-true', 0, 'Too Good to Be True? How to Tell If Youâ€™re Dating a Phony', 'sexndating', 0, '2018-08-15 19:52:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1627, 1, 'https://ca.askmen.com/dating/heidi_100/132_dating_girl.html', 0, 'Signs She\'s Not Into You', 'sexndating', 0, '2018-08-16 05:24:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1628, 1, 'http://www.theattractionforums.com/showthread.php?t=132622', 0, 'What to do when catching a girl lying who you just started dating?', 'sexndating', 0, '2018-08-16 11:42:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1629, 1, 'https://madamenoire.com/326409/check-really-bringing-table-relationships/', 0, 'Check Yourself: What Are You Really Bringing To The Table In Your Relationships?', 'sexndating', 0, '2018-08-16 16:26:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1630, 1, 'https://www.livecareer.com/interview/questions/what-can-you-offer-us-that-someone-else-cannot', 0, 'What Can You Offer Us That Someone Else Cannot?', 'society', 0, '2018-08-16 16:42:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1631, 1, 'https://www.bustle.com/p/11-subtle-signs-someone-may-be-uncomfortable-around-you-7662695', 0, '11 Subtle Signs Someone May Be Uncomfortable Around You', 'society', 0, '2018-08-16 18:48:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1632, 1, 'https://www.elitedaily.com/dating/five-questions-if-shes-the-one/1281427', 0, 'If You Can\'t Answer â€˜Yesâ€™ To These 5 Questions, She\'s Not The One', 'sexndating', 0, '2018-08-16 18:50:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1633, 1, 'https://www.inc.com/jeff-haden/17-signs-your-relationship-will-last-a-lifetime.html', 0, '17 Signs Your Relationship Will Last a Lifetime', 'sexndating', 0, '2018-08-16 18:52:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1634, 1, 'https://thoughtcatalog.com/holly-riordan/2018/05/questions-to-ask-a-girl/', 0, '250+ Questions To Ask A Girl If You Want To Know Who She REALLY Is', 'sexndating', 0, '2018-08-16 18:56:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1635, 1, 'http://www.longdistancerelationshipstatistics.com/', 0, 'Long Distance Relationship Statistics', 'sexndating', 0, '2018-08-16 19:11:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1636, 1, 'https://www.bustle.com/articles/168238-5-reasons-you-shouldnt-worry-if-you-dont-fight-with-your-partner', 0, '5 Reasons You Shouldn\'t Worry If You Don\'t Fight With Your Partner', 'sexndating', 0, '2018-08-16 19:18:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1637, 1, 'https://lifehacker.com/how-to-deal-with-assholes-1822977174', 0, 'How to Deal With Assholes', 'society', 0, '2018-08-17 01:50:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1638, 1, 'https://www.nature.com/articles/d41586-018-05980-7', 0, 'â€˜Green revolutionâ€™ crops bred to slash fertilizer use', 'scintech', 0, '2018-08-17 02:06:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1639, 1, 'https://gizmodo.com/elon-musk-on-whistleblower-accusing-tesla-of-illegally-1828399337', 0, 'Elon Musk on Whistleblower Accusing Tesla of Illegally Spying on Employee: \'This Guy Is Super [Nuts Emoji]\'', 'society', 0, '2018-08-17 03:43:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1640, 1, 'https://www.monster.ca/career-advice/article/getting-promoted-by-being-a-gossiper', 0, 'Embrace Gossip and Obtain a Promotion!', 'society', 0, '2018-08-17 03:59:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1641, 1, 'https://www.bodybuilding.com/content/10-ab-training-mistakes-you-need-to-stop-making.html', 0, '10 Ab Training Mistakes You Need To Stop Making!', 'body', 0, '2018-08-17 04:20:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1642, 1, 'https://www.wikihow.com/Deal-with-a-Lying-Best-Friend', 0, 'How to Deal with a Lying Best Friend', 'society', 0, '2018-08-20 05:37:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1643, 1, 'https://www.lovepanky.com/love-couch/broken-heart/valid-reasons-to-break-up-with-someone', 0, '14 Valid Reasons to Break Up with Someone', 'sexndating', 0, '2018-08-20 14:26:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1644, 1, 'https://www.pride.com/dating/2018/5/24/9-signs-girl-you-actually-you-and-not-just-being-polite', 0, '9 Signs the Girl You Like Is Actually Into You (and Not Just Being Polite)', 'sexndating', 0, '2018-08-20 14:40:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1645, 1, 'https://www.muscleandfitness.com/women/dating-advice/10-signs-shes-playing-you-chump', 0, '10 SIGNS SHE\'S PLAYING YOU LIKE A CHUMP', 'sexndating', 0, '2018-08-20 20:40:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1646, 1, 'https://www.majorleaguedating.com/signs-shes-playing-games-not-serious/', 0, '11 Signs Sheâ€™s Playing Games and Wasting Your Time', 'sexndating', 0, '2018-08-20 20:43:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1647, 1, 'https://thoughtcatalog.com/isis-nezbeth/2016/03/guys-heres-how-to-tell-if-youre-getting-played-by-a-woman-with-serious-game/', 0, 'Guys, Hereâ€™s How To Tell If Youâ€™re Getting Played By A Woman With Serious Game', 'sexndating', 0, '2018-08-20 20:56:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1648, 1, 'https://www.globalseducer.com/16-signs-she-is-playing-you/', 0, '16 Signs She is Playing You (The Painful Truth)', 'sexndating', 0, '2018-08-20 21:00:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1649, 1, 'https://www.thethailandlife.com/married-thailand-diy-day', 0, 'Getting Married in Thailand â€“ Do it Yourself in One Day!', 'sexndating', 0, '2018-08-20 21:18:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1650, 1, 'https://www.globalseducer.com/thai-girlfriend/', 0, '33 Reasons Why I Love My Thai Girlfriend', 'sexndating', 0, '2018-08-20 21:22:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1651, 1, 'https://www.globalseducer.com/chiang-mai-girls/', 0, 'Why Chiang Mai Girls are a Digital Nomadâ€™s Wet Dream', 'sexndating', 0, '2018-08-20 21:28:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1652, 1, 'https://bucketlistbombshells.com/total-foodies-guide-chiang-mai-thailand/', 0, 'A Total Foodies Guide To Chiang Mai, Thailand', 'worldnhistory', 0, '2018-08-20 21:41:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1653, 1, 'https://www.danwaldschmidt.com/articles/2010/08/attitude/the-ultimate-guide-to-handling-stupid-people', 0, 'THE ULTIMATE GUIDE TO HANDLING NEGATIVE PEOPLE', 'society', 0, '2018-08-21 09:57:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1654, 1, 'https://www.psychologytoday.com/ca/blog/living-forward/201609/4-ways-stop-feeling-insecure-in-your-relationships', 0, '4 Ways to Stop Feeling Insecure in Your Relationships', 'sexndating', 0, '2018-08-21 09:58:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1655, 1, 'http://digg.com/2018/tinder-horror-story-competition', 0, 'A Woman Tricked Dozens Of Guys On Tinder Into Showing Up For A Competition To Score A Date With Her', 'sexndating', 0, '2018-08-21 10:32:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1656, 1, 'https://www.quantamagazine.org/how-network-math-can-help-you-make-friends-20180820/', 0, 'How Network Math Can Help You Make Friends', 'society', 0, '2018-08-21 10:35:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1657, 1, 'http://digg.com/video/they-missed-you', 0, 'Golden Retrievers See Their Owner For The First Time In Six Months, Lose Their Damn Minds', 'society', 0, '2018-08-21 11:06:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1658, 1, 'https://www.npr.org/2018/08/20/640213152/venezuela-racked-with-hyperinflation-rolls-out-new-banknotes', 0, 'Venezuela, Racked With Hyperinflation, Rolls Out New Banknotes', 'worldnhistory', 0, '2018-08-21 11:09:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1659, 1, 'https://slate.com/human-interest/2018/08/the-worst-boss-stories-ive-heard-in-a-decade-plus-of-writing-a-workplace-advice-column.html', 0, 'Nightmare Bosses', 'society', 0, '2018-08-21 12:02:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1660, 1, 'http://nymag.com/selectall/2018/08/insecure-medical-devices-vulnerable-to-malicious-hacking.html', 0, 'The Fight to Secure Vulnerable Medical Devices From Hackers', 'scintech', 0, '2018-08-21 12:25:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1661, 1, 'https://www.quora.com/What-foods-are-the-best-to-break-your-intermittent-fast-and-why', 0, 'What foods are the best to break your intermittent fast and why?', 'body', 0, '2018-08-21 12:50:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1662, 1, 'https://www.nature.com/articles/d41586-018-06020-0', 0, 'Chief of Europeâ€™s â‚¬1-billion brain project steps down', 'worldnhistory', 0, '2018-08-21 19:09:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1663, 1, 'http://digg.com/2018/cohen-guilty-plea', 0, 'Michael Cohen Pleads Guilty To 8 Counts, Implicates Trump In Crimes', 'society', 0, '2018-08-21 21:06:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0);
INSERT INTO `articlelinks` (`linkid`, `linktype`, `link`, `imageid`, `title`, `category`, `articleid`, `createdate`, `revisedate`, `voteup`, `votedown`, `voteinternal`, `creatorid`, `numcomments`) VALUES
(1664, 1, 'https://www.cnn.com/2018/08/21/politics/paul-manafort-trial-jury/index.html', 0, 'Paul Manafort found guilty on eight counts', 'society', 0, '2018-08-21 21:07:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1665, 1, 'http://digg.com/video/image-editing-ai', 0, 'This AI Can Swap Out The Background Of Any Image', 'scintech', 0, '2018-08-21 21:10:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1666, 1, 'https://www.theguardian.com/technology/2018/aug/21/the-undertakers-of-silicon-valley-how-failure-became-big-business', 0, 'The undertakers of Silicon Valley: how failure became big business', 'worldnhistory', 0, '2018-08-21 21:36:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1667, 1, 'https://www.fighttips.com/punching-how-to-throw-a-hook/', 0, 'How to Throw a Lead Hook: Drills & Variations', 'body', 0, '2018-08-21 23:05:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1668, 1, 'https://www.popularmechanics.com/space/moon-mars/a22787591/scientists-find-direct-evidence-of-water-ice-on-the-lunar-surface/', 0, 'Scientists Find Direct Evidence of Water Ice on the Lunar Surface', 'scintech', 0, '2018-08-22 10:07:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1669, 1, 'https://www.theatlantic.com/politics/archive/2018/08/children-immigration-court/567490/', 0, 'The Thousands of Children Who Go to Immigration Court Alone', 'worldnhistory', 0, '2018-08-22 10:09:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1670, 1, 'https://www.youtube.com/watch?time_continue=238&v=mr9kK0_7x08', 0, 'Tesla Factory Tour with Elon Musk!', 'scintech', 0, '2018-08-22 10:16:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1671, 1, 'http://digg.com/2018/most-profitable-industries-states-mapped', 0, 'The Most Profitable Industry In Each State, Mapped', 'scintech', 0, '2018-08-22 11:05:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1672, 1, 'https://kinobody.com/diet-and-nutrition/intermittent-fasting-for-fat-loss/', 0, 'The Best Intermittent Fasting Meals For Losing Fat', 'body', 0, '2018-08-22 11:11:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1673, 1, 'https://www.blogto.com/eat_drink/2017/09/toronto-food-trends-summer-2017/', 0, 'The Top New Food Trends In Toronto 2018', 'worldnhistory', 0, '2018-08-22 15:52:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1674, 1, 'https://www.telegraph.co.uk/women/sex/women-do-go-looks-men-complicated/?li_source=LI&li_medium=li-recommendation-widget', 0, 'Women DO go for looks in men - but it\'s complicated', 'sexndating', 0, '2018-08-22 16:59:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1675, 1, 'https://www.blogto.com/toronto/the_best_milkshakes_in_toronto/', 0, 'The Best Milkshakes In Toronto', 'sexndating', 0, '2018-08-22 19:49:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1676, 1, 'https://www.narcity.com/ca/on/toronto/best-of-to/21-yummy-foods-for-under-10-to-try-in-toronto-this-summer', 0, '21 Yummy Foods For Under $10 To Try In Toronto This Summer', 'general', 0, '2018-08-23 12:59:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1677, 1, 'https://www.nature.com/articles/d41586-018-06004-0', 0, 'Mumâ€™s a Neanderthal, Dadâ€™s a Denisovan: First discovery of an ancient-human hybrid', 'scintech', 0, '2018-08-23 14:33:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1678, 1, 'http://www.wmcmuaythai.org/nai-khanomtom', 0, 'Nai Khanom Tom â€“ Muaythai Legends', 'worldnhistory', 0, '2018-08-24 01:18:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1679, 1, 'http://www.wmcmuaythai.org/about-muaythai/legends-of-muaythai', 0, 'Legends of Muay Thai', 'worldnhistory', 0, '2018-08-24 01:50:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1680, 1, 'https://www.allaboutfasting.com/breaking-a-fast.html', 0, 'Guidelines for Breaking a Fast', 'body', 0, '2018-08-24 11:01:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1681, 1, 'http://digg.com/video/deer-charges-dog', 0, 'Beagle Barks At A Deer, Gets Way More Than It Bargained For', 'general', 0, '2018-08-24 17:44:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1682, 1, 'https://www.muscleandfitness.com/women/sex-tips/why-wont-she-have-sex-me', 0, 'HERE\'S WHY SHE WON\'T HAVE SEX WITH YOU', 'sexndating', 0, '2018-08-24 18:07:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1683, 1, 'https://film.avclub.com/the-best-movies-of-1998-1828534340', 0, 'The best movies of 1998', 'cinema', 0, '2018-08-24 18:50:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1684, 1, 'https://www.vox.com/science-and-health/2018/8/24/17670582/how-to-sleep-better-tips-advice', 0, 'How to get a good nightâ€™s sleep', 'body', 0, '2018-08-24 18:51:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1685, 1, 'https://theworldpursuit.com/traveling-africa-expensive/', 0, 'Why is it Expensive to Travel to Africa?', 'worldnhistory', 0, '2018-08-24 22:28:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1686, 1, 'https://www.go2africa.com/african-travel-blog/african-safari-expensive', 0, 'WHY IS AN AFRICAN SAFARI EXPENSIVE?', 'worldnhistory', 0, '2018-08-24 23:01:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1687, 1, 'https://www.livestrong.com/article/88495-build-leg-muscle-speed/', 0, 'How to Build Leg Muscle for Speed', 'body', 0, '2018-08-25 15:32:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1688, 1, 'https://theoutline.com/post/6014/armie-hammer-serial-killer-face?zd=2&zi=ersx4zhf', 0, 'Armie Hammer could be the worldâ€™s most prolific serial killer', 'society', 0, '2018-08-25 23:08:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1689, 1, 'http://digg.com/video/baby-tastes-chocolate', 0, 'Baby Has Amazing Reaction To Tasting Chocolate For The First Time', 'general', 0, '2018-08-25 23:11:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1690, 1, 'http://digg.com/video/girl-loves-haircut', 0, '5-Year-Old Girl Gives The Happiest, Most Wholesome Speech After Receiving Her First Haircut', 'general', 0, '2018-08-25 23:13:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1691, 1, 'https://twincities.eater.com/2018/8/24/17777110/best-worst-new-minnesota-state-fair-foods-2018', 0, 'Critics Crown Minnesota State Fairâ€™s New Foods Winners and Losers', 'worldnhistory', 0, '2018-08-25 23:14:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1692, 1, 'https://www.psychologytoday.com/us/blog/prescriptions-life/201201/dont-try-reason-unreasonable-people', 0, 'Don\'t Try to Reason with Unreasonable People', 'general', 0, '2018-08-25 23:39:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1693, 1, 'https://www.nbcnews.com/news/us-news/sen-john-mccain-independent-voice-gop-establishment-dies-81-n790971', 0, 'Sen. John McCain, independent voice of the GOP establishment, dies at 81', 'worldnhistory', 0, '2018-08-26 01:16:04', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1694, 1, 'https://www.nature.com/articles/d41586-018-06068-y', 0, 'Massive Â£30-million grant will be awarded to one cardiovascular research team', 'scintech', 0, '2018-08-28 13:36:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1695, 1, 'https://www.muscleandfitness.com/workouts/workout-tips/10-reasons-youre-holding-body-fat', 0, '10 REASONS YOU\'RE HOLDING ONTO BODY FAT', 'body', 0, '2018-08-28 17:13:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1696, 1, 'https://www.thestar.com/life/food_wine/2015/01/01/bod_pod_accurately_accesses_body_composition.html', 0, 'Ryerson Universityâ€™s NExT Lab opens doors to high-tech diet and fitness testing', 'scintech', 0, '2018-08-29 03:48:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1697, 1, 'https://www.thestar.com/life/health_wellness/2015/09/21/pricey-test-reveals-that-calories-do-matter-but-dont-tell-all-about-weight-management.html', 0, 'Pricey test reveals that calories do matter but donâ€™t tell all about weight management', 'body', 0, '2018-08-29 04:01:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1698, 1, 'http://digg.com/video/cat-poops-on-girl', 0, 'First Bonding Experience Between Girl And Kitten Could Not Have Gone More Wrong', 'society', 0, '2018-08-29 18:08:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1699, 1, 'https://www.thecut.com/2018/08/what-does-it-mean-to-quantify-desirability.html?utm_source=nym&utm_medium=f1&utm_campaign=feed-part', 0, 'What Does It Mean to Quantify Desirability?', 'sexndating', 0, '2018-08-30 14:02:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1700, 1, 'https://motherboard.vice.com/en_us/article/7xqnze/in-major-breakthrough-scientists-observe-higgs-boson-decay-into-bottom-quarks', 0, 'Guy Spins Hobo Spider On Turntable To See If Spiders Get Dizzy', 'general', 0, '2018-08-30 14:09:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1701, 1, 'https://motherboard.vice.com/en_us/article/7xqnze/in-major-breakthrough-scientists-observe-higgs-boson-decay-into-bottom-quarks', 0, 'In Major Breakthrough, Scientists Observe Higgs Boson Decay into Bottom Quarks', 'scintech', 0, '2018-08-30 14:10:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1702, 1, 'http://www.vulture.com/2018/08/louis-ck-comedy-cellar-women-describe-rape-whistle-joke.html', 0, 'Two Women Describe Louis C.K.â€™s â€˜Uncomfortableâ€™ Comedy Cellar Set', 'society', 0, '2018-08-30 14:42:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1703, 1, 'https://www.nature.com/articles/d41586-018-06040-w', 0, 'Research is set up for bullies to thrive', 'scintech', 0, '2018-08-30 14:59:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1704, 1, 'https://www.breitbart.com/big-government/2018/08/30/justice-dept-charges-indian-ceo-with-massive-h-1b-fraud/', 0, 'Justice Dept. Charges Indian CEO With Massive H-1B Fraud', 'society', 0, '2018-08-31 16:33:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1705, 1, 'https://globalnews.ca/news/4420607/couple-ordered-funds-raised-homeless-man/', 0, 'Judge orders couple to turn over $400K raised for homeless man', 'worldnhistory', 0, '2018-08-31 17:49:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1706, 1, 'https://www.theatlantic.com/education/archive/2018/08/the-whitening-of-asian-americans/563336/', 0, 'The â€˜Whiteningâ€™ of Asian Americans', 'sexndating', 0, '2018-09-02 00:25:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1707, 1, 'https://www.bloomberg.com/news/articles/2018-08-29/fedex-d-diamonds-fueled-india-s-biggest-bank-fraud-report-says', 0, 'FedEx\'d Gems Fueled India\'s Biggest Bank Fraud, Report Says', 'worldnhistory', 0, '2018-09-02 00:29:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1708, 1, 'http://www.liftingrevolution.com/are-rest-days-necessary-even-if-im-not-sore-or-tired/', 0, 'Are Rest Days Necessary Even If Iâ€™m Not Sore Or Tired?', 'body', 0, '2018-09-02 04:28:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1709, 1, 'https://www.ncbi.nlm.nih.gov/pubmed/23727882', 0, 'Effects of psilocybin on hippocampal neurogenesis and extinction of trace fear conditioning.', 'body', 0, '2018-09-02 17:38:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1710, 1, 'https://www.cell.com/cell-reports/pdf/S2211-1247(18)30755-1.pdf', 0, 'Psychedelics Promote Structural and Functional Neural Plasticity', 'body', 0, '2018-09-02 17:38:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1711, 1, 'https://dzone.com/articles/the-curious-case-of-not-hiring-directly-into-softw', 0, 'The Curious Case of Not Hiring Directly into Software Engineer V (Or Whatever)', 'society', 0, '2018-09-02 17:51:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1712, 1, 'https://dzone.com/articles/the-evolution-of-systems-integration', 0, 'The Evolution of Systems Integration', 'scintech', 0, '2018-09-03 20:56:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1713, 1, 'https://www.fin24.com/Economy/ramaphosa-starts-with-a-recession-just-like-zuma-9-years-ago-20180904', 0, 'Ramaphosa starts with a recession, just like Zuma 9 years ago', 'worldnhistory', 0, '2018-09-05 03:15:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1714, 1, 'https://www.cnn.com/2018/09/06/asia/india-gay-sex-ruling-intl/index.html', 0, 'India\'s top court decriminalizes gay sex in landmark ruling', 'worldnhistory', 0, '2018-09-06 16:30:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1715, 1, 'https://www.theguardian.com/us-news/2018/sep/05/arizona-teachers-filipino-schools-low-pay', 0, 'The job Americans won\'t take: Arizona looks to Philippines to fill teacher shortage', 'worldnhistory', 0, '2018-09-06 16:31:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1716, 1, 'http://digg.com/video/ctrl-z-james-kennedy', 0, 'This Short About Love And Time Travel Is As Cute As It Is Nerdy', 'sexndating', 0, '2018-09-07 13:46:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1717, 1, 'https://www.citylab.com/life/2018/09/florence-italy-tourism-food/569476/', 0, 'Florence Is Fed Up With Tourists Eating in Public', 'worldnhistory', 0, '2018-09-07 14:20:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1718, 1, 'https://www.theatlantic.com/magazine/archive/2018/10/the-killer-in-the-cubicle/568303/', 0, 'A Shocking Number of Killers Murder Their Co-workers', 'society', 0, '2018-09-09 13:31:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1719, 1, 'https://www.youtube.com/watch?time_continue=537&v=YQVnHsLwRg4', 0, 'Can Americans Locate Asian Countries? | ASIAN BOSS', 'worldnhistory', 0, '2018-09-09 14:24:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1720, 1, 'https://www.wikihow.com/Date', 0, 'How To Date', 'sexndating', 0, '2018-09-10 03:06:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1721, 1, 'https://www.youtube.com/watch?v=E3wJrfC38VQ', 0, 'Amazing Cutting Shapes Dance', 'society', 0, '2018-09-10 04:54:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1722, 1, 'https://www.livestrong.com/article/550931-does-muscle-tissue-have-less-water-than-fat-tissue/', 0, 'Does Muscle Tissue Have Less Water Than Fat Tissue?', 'body', 0, '2018-09-10 11:38:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1723, 1, 'https://thevarsity.ca/2011/02/28/the-healthiest-take-out/', 0, 'The healthiest take-out', 'general', 0, '2018-09-10 18:00:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1724, 1, 'https://www.psychologytoday.com/ca/blog/the-teen-doctor/201701/15-ways-become-closer-others', 0, '15 Ways To Become Closer To Others', 'society', 0, '2018-09-11 05:27:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1725, 1, 'https://www.wikihow.com/Make-Close-Friends', 0, 'Expert Reviewed How to Make Close Friends', 'society', 0, '2018-09-11 05:29:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1726, 1, 'https://www.scienceofpeople.com/how-to-make-friends/', 0, 'Learn How to Make Friends As An Adult Using These 5 Steps', 'society', 0, '2018-09-11 05:37:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1727, 1, 'https://www.muscleandstrength.com/articles/shredded-cutting-diet-plans-eating-tips-freaky-physiques.html', 0, 'Get Shredded! Cutting Diet Plans & Eating Tips From Freaky Physiques', 'body', 0, '2018-09-11 14:51:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1728, 1, 'https://www.npr.org/sections/health-shots/2015/03/30/396384911/why-are-more-baby-boys-born-than-girls', 0, 'Why Are More Baby Boys Born Than Girls?', 'scintech', 0, '2018-09-11 15:27:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1729, 1, 'https://twocents.lifehacker.com/what-to-do-if-you-default-on-your-student-loans-1828946224', 0, 'What to Do if You Default on Your Student Loans', 'worldnhistory', 0, '2018-09-12 06:08:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1730, 1, 'http://digg.com/2018/hurricane-florence-updates', 0, 'Hurricane Florence Is Going To Be Bad â€” Here\'s Everything You Need To Know', 'worldnhistory', 0, '2018-09-12 21:01:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1731, 1, 'https://www.politico.com/magazine/story/2018/09/14/barack-obama-nukes-donald-trump-219912', 0, 'How Obama Made It Easier for Trump to Launch a Nuke', 'worldnhistory', 0, '2018-09-14 17:50:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1732, 1, 'https://www.psychologytoday.com/us/blog/disturbed/201208/why-you-dont-always-have-forgive', 0, 'Why You Don\'t Always Have to Forgive', 'society', 0, '2018-09-14 18:57:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1733, 1, 'https://www.youtube.com/watch?time_continue=2&v=qCbxYVY17Uo', 0, 'â€˜Cultâ€™ Leader Claims He Can Change The Weather I TRULY', 'society', 0, '2018-09-15 11:22:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1734, 1, 'http://digg.com/video/allison-mack-q-a', 0, 'Video Of \'Smallville\'-Star-Turned-Sex-Cult-Evangelist Allison Mack Raving About Her \'Self-Help Group\'', 'society', 0, '2018-09-15 11:26:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1735, 1, 'https://www.huffingtonpost.com/tuenight/no-i-dont-date-heres-why_b_6680618.html', 0, 'No, I Donâ€™t Date. Hereâ€™s Why', 'sexndating', 0, '2018-09-16 22:58:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1736, 1, 'https://www.eatthis.com/post-workout-protein-shake-causing-stomach-pain/', 0, 'Why Your Post-Workout Protein Shake Is Causing Stomach Pain', 'body', 0, '2018-09-18 19:49:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1737, 1, 'https://www.forbes.com/sites/jacquelynsmith/2013/02/07/what-to-do-when-a-co-worker-tries-to-sabotage-your-career/#6b469d262f8c', 0, 'What To Do When A Co-Worker Tries To Sabotage Your Career', 'society', 0, '2018-09-19 08:27:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1738, 1, 'https://www.cjr.org/criticism/jian-ghomeshi-john-hockenberry-ian-buruma.php', 0, 'On the confessions of fallen men', 'society', 0, '2018-09-19 10:37:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1739, 1, 'https://techcrunch.com/2018/09/18/the-gap-table/', 0, 'The Gap Table: Women own just 9% of startup equity', 'society', 0, '2018-09-19 10:40:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1740, 1, 'https://www.gq.com/story/how-puerto-rico-became-tax-haven-for-super-rich?mbid=synd_digg', 0, 'How Puerto Rico Became the Newest Tax Haven for the Super Rich', 'worldnhistory', 0, '2018-09-19 10:57:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1741, 1, 'https://longreads.com/2018/09/18/no-i-will-not-debate-you/', 0, 'No, I Will Not Debate You', 'society', 0, '2018-09-19 11:11:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1742, 1, 'https://www.vox.com/2018/9/18/17868074/financial-crisis-dodd-frank-lehman-brothers-recession', 0, 'How close are we to another financial crisis? 8 experts weigh in.', 'worldnhistory', 0, '2018-09-19 11:18:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1743, 1, 'https://highline.huffingtonpost.com/articles/en/everything-you-know-about-obesity-is-wrong/', 0, 'Everything You Know About Obesity Is Wrong', 'body', 0, '2018-09-19 15:35:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1744, 1, 'http://digg.com/video/pit-bulls-in-love', 0, 'We Forgot How Much Good There Is In The World And Then We Saw This Video Of Two Pit Bulls In Love', 'sexndating', 0, '2018-09-20 04:26:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1745, 1, 'https://www.nature.com/articles/d41586-018-06769-4', 0, 'Discovery of Galileoâ€™s long-lost letter shows he edited his heretical ideas to fool the Inquisition', 'worldnhistory', 0, '2018-09-21 14:21:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1746, 1, 'https://www.youtube.com/watch?time_continue=180&v=oqdD8FREgDw', 0, '50 People from 50 States Share the Weirdest Fact About Their State', 'worldnhistory', 0, '2018-09-21 15:25:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1747, 1, 'https://www.youtube.com/watch?v=4MRZbWuUmkk', 0, '70 People Reveal Their Country\'s Most Popular Stereotypes and ClichÃ©s', 'worldnhistory', 0, '2018-09-21 15:32:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1748, 1, 'https://www.youtube.com/watch?v=szFrHKoD1GE', 0, '70 People from 70 Countries Sing Their Country\'s National Anthem', 'worldnhistory', 0, '2018-09-21 15:37:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1749, 1, 'https://www.mensjournal.com/health-fitness/master-three-most-important-lifts/', 0, 'How to Master the 3 Most Important Lifts: Deadlift, Bench Press, and Squat', 'body', 0, '2018-09-23 00:51:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1750, 1, 'https://foodtolive.com/healthy-blog/pearl-barley-brown-rice/', 0, 'Pearl Barley Vs. Brown Rice: Which Is the Better Grain', 'body', 0, '2018-09-23 01:02:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1751, 1, 'https://youtu.be/vfDP2ONPPOU', 0, 'Can You Spot The Liar?', 'society', 0, '2018-09-23 16:05:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1752, 1, 'https://youtu.be/vfDP2ONPPOU', 0, 'Can You Spot The Liar?', 'society', 0, '2018-09-23 16:05:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1753, 1, 'https://www.newyorker.com/news/news-desk/senate-democrats-investigate-a-new-allegation-of-sexual-misconduct-from-the-supreme-court-nominee-brett-kavanaughs-college-years-deborah-ramirez?mbid=synd_digg', 0, 'Senate Democrats Investigate a New Allegation of Sexual Misconduct, from Brett Kavanaughâ€™s College Years', 'society', 0, '2018-09-24 00:17:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1754, 1, 'https://www.vox.com/first-person/2018/9/23/17890700/brett-kavanaugh-alyssa-milano-assault-allegations-why-i-didnt-report', 0, 'Alyssa Milano: I was sexually assaulted as a teen. Hereâ€™s why I didnâ€™t report.', 'society', 0, '2018-09-24 00:18:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1755, 1, 'https://www.theatlantic.com/business/archive/2018/09/stem-majors-jobs/568624/', 0, 'Itâ€™s Getting Harder for International STEM Students to Find Work After Graduation', 'worldnhistory', 0, '2018-09-24 13:55:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1756, 1, 'https://www.theguardian.com/world/2018/sep/24/new-us-tariffs-on-china-take-effect-with-no-compromise-in-sight', 0, 'New tariffs take effect as China accuses US of \'economic hegemony\' ', 'worldnhistory', 0, '2018-09-24 13:57:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1757, 1, 'https://www.washingtonpost.com/politics/im-not-the-president-of-the-globe-trump-goes-it-alone-as-he-faces-world-leaders-amid-trade-war-against-china/2018/09/23/fa351e58-bda2-11e8-8792-78719177250f_story.html?noredirect=on&utm_term=.e7256d2f5ae3', 0, 'Trump goes it alone as he faces world leaders amid trade war against China', 'worldnhistory', 0, '2018-09-24 13:59:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1758, 1, 'https://www.msn.com/en-ca/news/world/a-serial-rapist-eluded-police-for-years-then-they-searched-a-genealogy-site/ar-AAAz9bu?ocid=spartanntp', 0, 'A serial rapist eluded police for years. Then they searched a genealogy site.', 'worldnhistory', 0, '2018-09-24 18:05:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1759, 1, 'https://www.muscleandfitness.com/workouts/workout-tips/should-you-do-weight-training-cardio-same-day', 0, 'Research shows that combined training is not detrimental to muscle gains. ', 'body', 0, '2018-09-25 19:56:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1760, 1, 'https://www.active.com/fitness/articles/6-basic-weight-lifting-moves', 0, '6 Basic Weight-Lifting Moves', 'body', 0, '2018-09-25 21:49:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1761, 1, 'https://www.cnn.com/2018/09/25/us/cosby-prison-sci-phoenix/index.html', 0, 'Cosby heads to state prison SCI Phoenix to begin serving sentence', 'worldnhistory', 0, '2018-09-26 01:32:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1762, 1, 'https://www.bodybuilding.com/content/arnold-schwarzenegger-8-best-training-principles.html', 0, ' Arnold Schwarzenegger\'s 8 Best Training Principles', 'body', 0, '2018-09-26 03:11:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1763, 1, 'http://digg.com/2018/brett-kavanaugh-accusers-how-many', 0, ' Third Kavanaugh Accuser Breaks Her Silence, Implicating Kavanaugh And Mark Judge In Gang Rape ', 'society', 0, '2018-09-26 16:42:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1764, 1, 'https://www.careerkey.org/explore-career-options/military-career.html#.W6yh0Pb_q00', 0, 'Choosing a Military Career', 'worldnhistory', 0, '2018-09-27 08:26:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1765, 1, 'https://www.theguardian.com/business/2018/sep/25/monsanto-dewayne-johnson-cancer-verdict', 0, ' The man who beat Monsanto: \'They have to pay for not being honest\'', 'worldnhistory', 0, '2018-09-27 08:29:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1766, 1, 'https://melmagazine.com/the-men-who-deliberately-friend-zone-themselves-ff5262a4319c', 0, 'The Men Who Deliberately Friend-Zone Themselves', 'sexndating', 0, '2018-09-27 08:53:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1767, 1, 'https://health.usnews.com/health-news/blogs/on-fitness/2010/11/05/10-signs-youre-exercising-too-much', 0, '10 Signs You\'re Exercising Too Much', 'body', 0, '2018-09-28 08:18:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1768, 1, 'http://digg.com/video/cow-plays-fetch', 0, ' Happy White Cow Doesn\'t Want To Stop Playing Fetch With Her Human ', 'worldnhistory', 0, '2018-09-28 16:13:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1769, 1, 'http://nautil.us/issue/64/the-unseen/the-curious-case-of-the-bog-bodies-rp', 0, 'The Curious Case of the Bog Bodies', 'worldnhistory', 0, '2018-09-28 16:16:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1770, 1, 'https://www.theguardian.com/world/2018/sep/28/duterte-confesses-my-only-sin-is-the-extrajudicial-killings', 0, ' Duterte confesses: \'My only sin is the extrajudicial killings\'', 'worldnhistory', 0, '2018-09-28 16:21:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1771, 1, 'https://www.gq.com/story/100000-dollar-engagement-ring?mbid=synd_digg', 0, 'He Bought Her a $100,000 Engagement Ringâ€”Then They Broke Up and Things Really Got Messy', 'sexndating', 0, '2018-09-30 13:48:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1772, 1, 'https://www.vice.com/en_us/article/ywk9av/former-inmates-told-us-how-they-beat-drug-tests-while-behind-bars', 0, 'Former Inmates Told Us How They Beat Drug Tests While Behind Bars', 'society', 0, '2018-09-30 14:00:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1773, 1, 'https://www.youtube.com/watch?v=su2nCp4AkKI', 0, 'Never Trust Deceptive Women', 'sexndating', 0, '2018-10-01 14:38:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1774, 1, 'https://www.youtube.com/watch?v=nf5g97cXdCo', 0, 'How To Tell If She\'s Cheating', 'sexndating', 0, '2018-10-01 14:47:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1775, 1, 'http://digg.com/2018/cristiano-ronaldo-rape-allegation', 0, ' What We Know About Cristiano Ronaldo\'s Secret Rape Settlement ', 'society', 0, '2018-10-01 15:19:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1776, 1, 'https://www.youtube.com/watch?v=qZheHYwYOqI', 0, 'Nice Guys Get No Respect', 'general', 0, '2018-10-01 15:45:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1777, 1, 'http://theweek.com/articles/797822/disney-ideas', 0, 'Disney is out of ideas', 'cinema', 0, '2018-10-01 18:57:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1778, 1, 'https://www.theatlantic.com/technology/archive/2018/10/agents-of-automation/568795/', 0, 'The Coders Programming Themselves Out of a Job', 'scintech', 0, '2018-10-03 06:34:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1779, 1, 'https://www.cnet.com/news/trump-text-testing-femas-new-presidential-alert-system-sent-across-us/', 0, 'Trump Presidential Alert: FEMA\'s new emergency test deployed', 'worldnhistory', 0, '2018-10-04 04:30:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1780, 1, 'https://www.bloomberg.com/news/articles/2018-10-03/tesla-s-model-3-is-becoming-one-of-america-s-best-selling-sedans', 0, 'Teslaâ€™s Model 3 Is Becoming One of Americaâ€™s Best-Selling Sedans', 'general', 0, '2018-10-04 05:19:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1781, 1, 'http://nautil.us/issue/65/in-plain-sight/your-iq-matters-less-than-you-think', 0, 'Your IQ Matters Less Than You Think', 'scintech', 0, '2018-10-04 14:57:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1782, 1, 'https://www.youtube.com/watch?time_continue=1&v=aYIfGA5QbL0', 0, 'The Attack on Pearl Harbor - Surprise Military Strike by the Imperial Japanese Navy Service', 'worldnhistory', 0, '2018-10-04 15:06:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1783, 1, 'http://www.bbc.com/future/story/20181002-how-long-did-ancient-people-live-life-span-versus-longevity?ocid=global_future_rss', 0, 'Do We Really Live Longer Than Our Ancestors? ', 'body', 0, '2018-10-04 15:07:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1784, 1, 'https://www.theguardian.com/us-news/commentisfree/2018/oct/04/few-us-politicians-working-class', 0, 'Why are so few US politicians from the working class?', 'society', 0, '2018-10-05 06:33:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1785, 1, 'https://www.pastemagazine.com/articles/2018/10/the-50-best-anime-series-of-all-time.html', 0, 'The 50 Best Anime Series of All Time', 'cinema', 0, '2018-10-05 06:37:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1786, 1, 'https://splinternews.com/too-sick-too-pregnant-too-well-paid-walmart-workers-1829438698', 0, 'Too Sick, Too Pregnant, Too Well Paid: Walmart Workers on Why the Company Fires Them', 'society', 0, '2018-10-05 06:40:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1787, 1, 'https://www.themarshallproject.org/2018/10/03/banished', 0, 'Bands of nomadic sex offenders and a cat-and-mouse game to move them', 'society', 0, '2018-10-05 07:10:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1788, 1, 'https://www.buzzfeednews.com/article/maryanngeorgantopoulos/kavanaugh-fbi', 0, 'The FBI Finished Its New Brett Kavanaugh Investigation Without Interviewing Brett Kavanaugh', 'society', 0, '2018-10-05 07:25:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1789, 1, 'https://www.theguardian.com/global/2018/oct/04/ontario-six-nations-nestle-running-water', 0, 'While NestlÃ© extracts millions of litres from their land, residents have no drinking water', 'scintech', 0, '2018-10-05 07:26:08', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1790, 1, 'https://www.citylab.com/transportation/2018/10/where-are-great-transit-candidates/572059/', 0, 'Why Do Candidates Ignore Mass Transit?', 'society', 0, '2018-10-05 15:19:49', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1791, 1, 'http://digg.com/2018/who-is-responsible-market-growth', 0, 'This Data Visualization Shows What\'s Really Responsible For Our Current Bull Market', 'scintech', 0, '2018-10-05 15:21:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1792, 1, 'https://www.nbcnews.com/business/economy/unemployment-its-lowest-level-1969-n916996', 0, 'Unemployment is at its lowest level in nearly 50 years, new jobs report shows', 'worldnhistory', 0, '2018-10-05 15:23:12', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1793, 1, 'https://melmagazine.com/he-was-an-infamous-college-hacker-then-a-bitcoin-millionaire-now-hes-charged-with-depraved-murder-f06f563c6fe0', 0, 'He Was an Infamous College Hacker. Then a Bitcoin Millionaire. Now Heâ€™s Charged With â€˜Depravedâ€™ Murder.', 'worldnhistory', 0, '2018-10-05 15:40:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1794, 1, 'http://www.grubstreet.com/2018/10/forgotten-crops-fonio-quinoa.html', 0, 'The Quest to Create the Next Quinoa Can Americans be convinced to eat ancient foods theyâ€™ve never heard of?', 'body', 0, '2018-10-05 15:42:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1795, 1, 'https://www.alive.com/family/6-ways-to-boost-male-fertility-naturally/', 0, '6-ways-to-boost-male-fertility-naturally', 'body', 0, '2018-10-06 03:58:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1796, 1, 'https://stronglifts.com/build-muscle/', 0, 'How to Build Muscle Naturally: The Definitive Guide', 'body', 0, '2018-10-06 08:13:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1797, 1, 'http://www.renegadeworkouts.com/if-i-could-only-do-3-exercises-to-get-big/', 0, 'If I Could Only Do 3 Exercises to Get Big', 'body', 0, '2018-10-06 09:30:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1798, 1, 'http://listverse.com/2013/01/25/9-fairy-tales-with-sinister-morals/', 0, '9 Fairy Tales with Sinister Morals', 'worldnhistory', 0, '2018-10-08 15:13:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1799, 1, 'https://www.youtube.com/watch?v=_XneTBhRPYk', 0, 'Hidden Camera Exposes Apple\'s Genius Bars Ripping Off Customers', 'society', 0, '2018-10-09 17:56:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1800, 1, 'https://arcdigital.media/china-is-building-a-social-credit-system-so-is-the-united-states-a9facbc6f832', 0, 'China Is Building A \'Social Credit\' System. So Is The United States.', 'worldnhistory', 0, '2018-10-09 18:31:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1801, 1, 'http://digg.com/video/people-watching-online-dating-feminism', 0, 'The Differences Between Dating As A Man And As A Woman, Illustrated Perfectly By A Witty Cartoon', 'sexndating', 0, '2018-10-11 05:37:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1802, 1, 'https://www.quantamagazine.org/interstellar-comet-oumuamua-might-not-actually-be-a-comet-20181010/', 0, 'Interstellar Visitor Found to Be Unlike a Comet or an Asteroid', 'scintech', 0, '2018-10-11 05:38:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1803, 1, 'https://research.stlouisfed.org/publications/economic-synopses/2017/08/25/earnings-losses-through-unemployment-and-unemployment-duration/', 0, 'Earnings Losses Through Unemployment and Unemployment Duration', 'society', 0, '2018-10-11 13:50:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1804, 1, 'https://slate.com/human-interest/2018/10/kara-swisher-interview-best-worst-bosses.html', 0, 'What I learned from the worstâ€”and bestâ€”bosses Iâ€™ve ever had.', 'society', 0, '2018-10-12 05:05:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1805, 1, 'http://digg.com/2018/strong-men-poop', 0, 'The World\'s Strongest Men Poop A Lot, And Other Facts', 'body', 0, '2018-10-12 15:14:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1806, 1, 'http://www.bbc.com/future/story/20181011-how-to-solve-delhis-water-crisis', 0, 'The World\'s Second Biggest City Running Out Of Water', 'worldnhistory', 0, '2018-10-12 17:21:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1807, 1, 'https://jalopnik.com/the-strangest-desert-festival-in-the-world-makes-everyo-1829467474', 0, 'The Strangest Desert Festival In the World Makes Everyoneâ€™s Mad Max Dreams Come True', 'worldnhistory', 0, '2018-10-12 17:21:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1808, 1, 'http://digg.com/video/otter-sounds', 0, 'The Noises Hungry Otters Make Do Not Even Sound Real', 'scintech', 0, '2018-10-12 17:23:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1809, 1, 'https://www.youtube.com/watch?v=QPnxOOeY1Kg', 0, 'How the upper middle class keeps everyone else out', 'worldnhistory', 0, '2018-10-12 19:33:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1810, 1, 'https://www.vox.com/the-goods/2018/10/12/17969190/wework-lawsuit-sexual-assault-harassment-retaliation', 0, 'A WeWork employee says she was fired after reporting sexual assault. The company says her claims are meritless', 'society', 0, '2018-10-12 21:52:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1811, 1, 'http://nautil.us/issue/65/in-plain-sight/have-balloons-and-ice-broken-the-standard-model', 0, 'Have Balloons and Ice Broken the Standard Model?', 'scintech', 0, '2018-10-13 02:48:47', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1812, 1, 'https://www.bbc.co.uk/news/resources/idt-sh/moving_to_Chernobyl', 0, 'The people who moved to Chernobyl', 'scintech', 0, '2018-10-13 02:53:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1813, 1, 'https://phys.org/news/2018-10-world-fastest-camera-trillion.html', 0, 'World\'s fastest camera freezes time at 10 trillion frames per second', 'scintech', 0, '2018-10-13 13:59:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1814, 1, 'https://www.zdnet.com/article/a-mysterious-grey-hat-is-patching-peoples-outdated-mikrotik-routers/', 0, 'A mysterious grey-hat is patching people\'s outdated MikroTik routers', 'scintech', 0, '2018-10-13 18:30:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1815, 1, 'http://www.aesopfables.com/aesop4.html', 0, 'Aesop\'s Fables', 'worldnhistory', 0, '2018-10-14 06:17:55', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1816, 1, 'https://core.ac.uk/download/pdf/82357053.pdf', 0, 'Measuring Hitting Force', 'scintech', 0, '2018-10-14 08:17:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1817, 1, 'https://www.cnbc.com/2018/10/15/microsoft-co-founder-paul-allen-dies-of-cancer-at-age-65.html', 0, 'Microsoft co-founder Paul Allen dies of cancer at age 65', 'worldnhistory', 0, '2018-10-16 06:38:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1818, 1, 'https://www.npr.org/2018/10/15/657551289/ex-senate-intelligence-staffer-who-dated-reporter-pleads-guilty-to-lying-to-fbi', 0, 'Ex-Senate Intelligence Staffer Who Dated Reporter Pleads Guilty To Lying To FBI', 'worldnhistory', 0, '2018-10-16 06:40:42', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1819, 1, 'https://www.npr.org/sections/health-shots/2018/10/15/657493767/if-your-medical-information-becomes-a-moneymaker-could-you-could-get-a-cut', 0, 'If Your Medical Information Becomes A Moneymaker, Could You Get A Cut?', 'worldnhistory', 0, '2018-10-16 06:46:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1820, 1, 'https://www.nature.com/articles/d41586-018-07018-4', 0, 'Astronomy is losing women three times faster than men', 'worldnhistory', 0, '2018-10-16 13:34:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1821, 1, 'https://www.nature.com/articles/d41586-018-06999-6', 0, 'Healthy mice from same-sex parents have their own pups', 'scintech', 0, '2018-10-16 14:11:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1822, 1, 'https://www.youtube.com/watch?time_continue=94&v=i_RunwNoKUw', 0, 'How to fight in full 14th centruy harness', 'worldnhistory', 0, '2018-10-16 16:20:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1823, 1, 'http://digg.com/2018/trump-horseface-stormy-daniels', 0, 'President Trump Takes To Twitter To Call Stormy Daniels \'Horseface\'', 'society', 0, '2018-10-16 16:27:11', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1824, 1, 'https://www.youtube.com/watch?time_continue=530&v=KL8vRRO1Wl8', 0, 'Catch and Cook BOILED Fish ** Underwater Fishing Camera', 'worldnhistory', 0, '2018-10-16 21:27:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1825, 1, 'https://www.thecut.com/2018/10/nicer-people-tend-to-have-less-savings-and-more-debt.html', 0, 'I May Be Drowning in Student Loan Debt, But at Least Iâ€™m Nice', 'worldnhistory', 0, '2018-10-17 03:27:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1826, 1, 'https://fivethirtyeight.com/features/what-happens-when-humans-fall-in-love-with-an-invasive-species/', 0, 'What Happens When Humans Fall In Love With An Invasive Species', 'sexndating', 0, '2018-10-17 04:49:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1827, 1, 'https://www.buzzfeednews.com/article/aramroston/mercenaries-assassination-us-yemen-uae-spear-golan-dahlan', 0, 'American Mercenaries Were Hired To Assassinate Politicians In The Middle East', 'worldnhistory', 0, '2018-10-17 04:51:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1828, 1, 'https://www.youtube.com/watch?v=yCpsQ8LZOco', 0, 'Caltech Researchers Invented This Crazy Illusion That Uses Sound To Make You See Something That Doesn\'t Exist', 'body', 0, '2018-10-17 04:58:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1829, 1, 'http://www.nbcnews.com/id/4900364/ns/nbc_nightly_news_with_brian_williams/t/why-steroid-use-so-tempting/#.W8fqN2hKjIU', 0, 'Why steroid use is so tempting', 'body', 0, '2018-10-18 01:07:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1830, 1, 'https://www.washingtonpost.com/news/national/wp/2018/10/17/feature/witness-to-the-killing/?noredirect=on&utm_term=.95d3fe58df8c', 0, 'Witness to the killing', 'worldnhistory', 0, '2018-10-18 03:40:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1831, 1, 'https://ca.yahoo.com/news/convicted-killer-william-sandeson-sues-090000101.html', 0, 'Convicted killer William Sandeson sues private detective that tipped off police', 'society', 0, '2018-10-18 16:37:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1832, 1, 'https://ourworldindata.org/literacy', 0, 'Literacy', 'worldnhistory', 0, '2018-10-18 18:13:16', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1833, 1, 'https://torontolife.com/city/queen-west-voyeur/', 0, 'INSIDE THE MIND OF A VOYEUR', 'worldnhistory', 0, '2018-10-18 18:14:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1834, 1, 'https://www.thecut.com/2018/10/sex-with-an-ex-why.html', 0, 'The Therapeutic Effects of Sleeping With an Ex', 'sexndating', 0, '2018-10-18 20:00:14', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1835, 1, 'https://www.quantamagazine.org/why-the-many-worlds-interpretation-of-quantum-mechanics-has-many-problems-20181018/', 0, 'Why the Many-Worlds Interpretation Has Many Problems', 'scintech', 0, '2018-10-18 22:06:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1836, 1, 'https://www.verywellfit.com/squat-modifications-for-sore-knees-1231332', 0, 'Squat Modifications for Sore Knees', 'body', 0, '2018-10-21 01:45:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1837, 1, 'https://melmagazine.com/en-us/story/yes-you-can-be-sued-for-trying-to-save-someones-life', 0, 'YES, YOU CAN BE SUED FOR TRYING TO SAVE SOMEONEâ€™S LIFE', 'society', 0, '2018-10-21 14:07:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1838, 1, 'https://imgur.com/gallery/D2Hl1', 0, '50 dark humour jokes for those going through life unoffended and want to change that.', 'general', 0, '2018-10-21 14:16:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1839, 1, 'https://memesbams.com/offensive-jokes-messed-up-jokes/', 0, 'Offensive Jokes & Messed Up Jokes', 'general', 0, '2018-10-21 14:17:00', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1840, 1, 'https://imgur.com/gallery/o0Xpw', 0, '50 of the most offensive jokes I know', 'general', 0, '2018-10-21 14:17:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1841, 1, 'https://short-funny.com/sarcasm-black-humor.php', 0, 'The Best of Black Humor / Dark Jokes ', 'general', 0, '2018-10-21 14:19:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1842, 1, 'http://jokes.cc.com/funny-dark-humor', 0, 'DARK HUMOR', 'general', 0, '2018-10-21 14:20:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1843, 1, 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5004623/', 0, 'Ethnic differences in bone geometry between White, Black and South Asian men in the UK', 'body', 0, '2018-10-21 14:30:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1844, 1, 'https://worstjokesever.com/morbid-jokes', 0, 'Morbid Jokes', 'general', 0, '2018-10-21 14:33:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1845, 1, 'https://thoughtcatalog.com/melanie-berliet/2015/03/50-dirty-jokes-that-are-never-appropriate-but-always-funny/', 0, '50 Dirty Jokes That Are (Never Appropriate But) Always Funny', 'general', 0, '2018-10-21 20:57:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1846, 1, 'https://medium.freecodecamp.org/how-to-create-an-expense-manager-using-entity-framework-core-and-highcharts-32f3b1ad0dbc', 0, 'How to create an expense manager using Entity Framework Core and Highcharts', 'scintech', 0, '2018-10-22 12:11:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1847, 1, 'https://nationalpost.com/news/toronto/rohinie-bisesar-files-appeal-behind-lawyers-back', 0, 'Accused Toronto financial district killer files appeal behind lawyer\'s back', 'society', 0, '2018-10-22 16:51:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1848, 1, 'https://www.youtube.com/watch?time_continue=60&v=ZzpY3gJgXQw', 0, 'Stick, Snake or caterpillar?', 'worldnhistory', 0, '2018-10-22 21:11:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1849, 1, 'https://www.ctvnews.ca/politics/liberals-write-off-6-3-billion-in-loans-including-2-6-billion-to-automaker-1.4144249', 0, 'Liberals write off $6.3 billion in loans, including $2.6 billion to automaker', 'general', 0, '2018-10-22 21:31:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1850, 1, 'https://www.huffingtonpost.ca/2018/10/21/milton-ont-psychic-dorie-madeena-stevenson-charged-with-witchcraft_a_23567392/', 0, 'Milton, Ont. â€˜Psychicâ€™ Dorie \'Madeena\' Stevenson Charged With \'Witchcraft\'', 'general', 0, '2018-10-22 21:32:35', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1851, 1, 'https://www.fool.ca/2018/10/22/the-3-best-cannabis-stocks-on-the-tsx-index/', 0, 'The 3 Best Cannabis Stocks on the TSX Index', 'worldnhistory', 0, '2018-10-22 21:32:57', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1852, 1, 'https://nationalpost.com/news/politics/after-sexual-misconduct-allegations-forced-him-from-politics-patrick-brown-makes-comeback-in-brampton', 0, 'After sexual misconduct allegations forced him from politics, Patrick Brown makes comeback in Brampton', 'society', 0, '2018-10-23 12:45:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1853, 1, 'https://www.nature.com/articles/d41586-018-07115-4', 0, 'Virus detectives test whole-body scans in search of HIVâ€™s hiding places', 'body', 0, '2018-10-23 14:01:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1854, 1, 'https://www.fool.ca/2018/10/23/marijuana-stocks-is-the-latest-crash-in-pot-stocks-a-buying-opportunity/', 0, 'Marijuana Stocks: Is the Latest Crash in Pot Stocks a Buying Opportunity?', 'worldnhistory', 0, '2018-10-23 15:16:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1855, 1, 'https://www.aljazeera.com/news/2018/10/suspected-explosive-device-george-soros-york-home-181023102453417.html', 0, 'Suspected explosive device found at George Soros\'s New York home', 'worldnhistory', 0, '2018-10-23 15:16:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1856, 1, 'https://www.cbc.ca/news/canada/newfoundland-labrador/mcp-covering-hiv-prevention-pills-1.4874317', 0, 'HIV prevention drug PrEP now covered under provincial drug plan', 'society', 0, '2018-10-23 15:18:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1857, 1, 'https://business.financialpost.com/technology/waterloo-based-thalmic-labs-unveils-augmented-reality-smart-glasses', 0, 'Waterloo-based Thalmic Labs unveils augmented reality smart glasses', 'scintech', 0, '2018-10-23 15:19:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1858, 1, 'https://slate.com/human-interest/2018/10/hedda-nussbaum-joel-steinberg-abuse-trial-anniversary.html', 0, 'Thirty Years Later, Can We Finally Forgive Hedda Nussbaum?', 'worldnhistory', 0, '2018-10-25 13:01:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1859, 1, 'https://www.wired.com/story/regulatory-hacking-evan-burfield-doing-good-getting-rich/?mbid=synd_digg', 0, 'REGULATORY HACKERS AREN\'T FIXING SOCIETY. THEY\'RE GETTING RICH', 'society', 0, '2018-10-25 13:03:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1860, 1, 'https://www.theatlantic.com/science/archive/2018/10/crypt-of-civilization-racism/573598/', 0, 'A Racist Message Buried for Thousands of Years in the Future', 'worldnhistory', 0, '2018-10-25 13:53:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1861, 1, 'https://www.youtube.com/watch?time_continue=40&v=oiOzaBVgd9U', 0, 'Why It\'s Common For You To Be Depressed In Your 30s', 'body', 0, '2018-10-26 15:50:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1862, 1, 'http://www.muaythaischolar.com/sponsored-fighter-in-thailand/', 0, 'How to Become a Sponsored Fighter in Thailand', 'worldnhistory', 0, '2018-10-27 00:34:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1863, 1, 'https://www.nature.com/articles/d41586-018-07135-0', 0, 'Self-driving car dilemmas reveal that moral choices are not universal', 'worldnhistory', 0, '2018-10-27 03:05:19', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1864, 1, 'https://www.youtube.com/watch?v=R8tG3hlHcPg', 0, 'Can a Country Ban Students From Kissing, Even at Home? | NBC Left Field', 'worldnhistory', 0, '2018-10-28 07:10:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1865, 1, 'https://www.outsideonline.com/2358586/dont-worry-about-exercising-too-much', 0, 'Don\'t Worry About Exercising Too Much', 'body', 0, '2018-10-29 03:28:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1866, 1, 'https://hazlitt.net/longreads/psychopaths-and-rest-us#.W9tdRhgopVc.twitter', 0, 'Psychopaths and the Rest of Us', 'society', 0, '2018-11-02 17:33:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1867, 1, 'https://newrepublic.com/article/151994/china-many-school-stabbings', 0, 'Why Does China Have So Many School Stabbings?', 'worldnhistory', 0, '2018-11-04 17:11:09', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1868, 1, 'https://www.youtube.com/watch?time_continue=36&v=Krd2tVaP3z8', 0, 'Movies That Take Place in the 1990s', 'cinema', 0, '2018-11-04 17:12:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1869, 1, 'http://digg.com/2018/best-advice-columns-racist-coworkers', 0, 'I Paid Off My Wife\'s Student Loans And Then She Divorced Me', 'sexndating', 0, '2018-11-05 20:03:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1870, 1, 'https://www.dawn.com/news/1443970', 0, '\'Almost all\' Pakistani banks hacked in security breach, says FIA cybercrime head', 'worldnhistory', 0, '2018-11-07 16:55:17', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1871, 1, 'https://lendedu.com/blog/colleges-make-most-money-from-applications/', 0, 'Which Colleges Bring in the Most Money From Applications?', 'worldnhistory', 0, '2018-11-12 07:58:10', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1872, 1, 'https://www.youtube.com/watch?v=5F7XwjUgK8o', 0, 'A Fascinating Look Inside Of A Luxury Doomsday Bunker From The 1960s', 'scintech', 0, '2018-11-13 00:40:43', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1873, 1, 'https://motherboard.vice.com/en_us/article/pa5d9g/what-constant-surveillance-does-to-your-brain', 0, 'What Constant Surveillance Does to Your Brain', 'scintech', 0, '2018-11-14 15:00:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1874, 1, 'http://www.bbc.com/future/story/20181112-severely-deficient-autobiographical-memory-is-surprisi', 0, 'The inability to â€˜mentally time travelâ€™ is the latest memory condition to intrigue researchers', 'body', 0, '2018-11-14 15:03:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1875, 1, 'https://qz.com/1443640/being-single-in-your-30s-isnt-bad-luck-its-a-global-phenomenon/', 0, 'Being single in your 30s isnâ€™t bad luck, itâ€™s a global phenomenon', 'sexndating', 0, '2018-11-14 15:03:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1876, 1, 'http://digg.com/2018/homeless-man-gofundme-swindled', 0, 'The Saga Of The Couple Who \'Swindled\' A Homeless Man Out Of $400K Just Took A Wild Turn', 'society', 0, '2018-11-15 17:23:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1877, 1, 'https://www.buzzfeednews.com/article/johnstanton/metoo-men-escaping-mexico-sex-workers', 0, 'Sex Tourists Say They\'re Going To Mexico To Escape #MeToo', 'worldnhistory', 0, '2018-11-16 17:31:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0);
INSERT INTO `articlelinks` (`linkid`, `linktype`, `link`, `imageid`, `title`, `category`, `articleid`, `createdate`, `revisedate`, `voteup`, `votedown`, `voteinternal`, `creatorid`, `numcomments`) VALUES
(1878, 1, 'https://www.nature.com/articles/d41586-018-07402-0', 0, 'Lab-grown â€˜mini brainsâ€™ produce electrical patterns that resemble those of premature babies', 'scintech', 0, '2018-11-17 05:56:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1879, 1, 'https://www.dailymail.co.uk/news/article-6384735/Adorable-video-shows-kindergartners-choose-want-met-classroom-greeter.html', 0, 'Adorable video shows Wisconsin kindergartners hugging and fist-bumping their â€˜class greeterâ€™', 'society', 0, '2018-11-19 05:58:52', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1880, 1, 'http://digg.com/video/kama-sutra-explained', 0, 'Why The Kama Sutra Is About A Lot More Than Sex (But, Yes, It\'s About Sex)', 'sexndating', 0, '2018-11-19 06:20:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1881, 1, 'https://migrationology.com/how-i-was-able-to-throw-away-my-fat-pants-while-eating-in-asia/', 0, 'How I Was Able To Throw Away My Fat Pants While Eating In Asia', 'body', 0, '2018-11-22 04:04:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1882, 1, 'https://www.nature.com/articles/d41586-018-07485-9', 0, 'Watch: Plane with no moving parts takes first flight', 'scintech', 0, '2018-11-22 13:15:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1883, 1, 'https://www.nytimes.com/2018/10/15/us/harvard-affirmative-action-asian-americans.html', 0, 'Does Harvard Admissions Discriminate? The Lawsuit on Affirmative Action, Explained', 'society', 0, '2018-11-22 18:40:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1884, 1, 'https://qz.com/1470374/womens-sexual-rights-include-the-right-to-pleasure/', 0, 'Womenâ€™s sexual rights include the right to pleasure', 'society', 0, '2018-11-26 05:04:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1885, 1, 'https://slate.com/technology/2018/11/dhs-credit-scores-legal-resident-assessment.html', 0, 'Your Credit Score Isnâ€™t a Reflection of Your Moral Character', 'society', 0, '2018-11-26 08:42:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1886, 1, 'https://www.thedailybeast.com/inside-the-forgotten-assault-allegation-against-stormy-daniels', 0, 'The Forgotten Assault Allegation Against Stormy Daniels', 'society', 0, '2018-11-26 08:45:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1887, 1, 'http://digg.com/video/saving-money-hacks', 0, 'Here Are A Few Useful Tips For Saving Money You\'ve Probably Never Tried Before', 'society', 0, '2018-11-26 08:46:40', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1888, 1, 'https://www.buzzfeed.com/alanwhite/brexit-deal-endorsed-eu-may-tusk', 0, 'The EU Has Approved A Brexit Deal With Britain', 'worldnhistory', 0, '2018-11-26 08:48:02', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1889, 1, 'https://newrepublic.com/article/152366/monica-lewinskys-long-road-vindication', 0, 'How Blair Fosterâ€™s documentary \'The Clinton Affair\' reassesses history in the wake of the MeToo movement', 'worldnhistory', 0, '2018-11-26 08:49:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1890, 1, 'https://www.popsci.com/how-to-talk-to-your-kids-about-santa-claus', 0, 'Should Parents Lie To Kids About Santa Claus? We Asked The Experts', 'society', 0, '2018-11-26 08:51:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1891, 1, 'https://undark.org/article/new-tech-rape-kit-backlog/', 0, 'Can New Technology Put a Dent in the Rape Kit Backlog?', 'scintech', 0, '2018-11-27 12:33:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1892, 1, 'http://digg.com/2018/prep-effects-hiv-preventi', 0, 'The Unexpected Effects Of The HIV Prevention Pill', 'scintech', 0, '2018-11-27 20:26:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1893, 1, 'https://motherboard.vice.com/en_us/article/8xp593/an-ancient-virus-is-probably-why-weed-gets-you-high', 0, 'Ancient Viruses Are Probably Why Weed Has THC and CBD', 'scintech', 0, '2018-11-29 09:55:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1894, 1, 'https://www.nationalgeographic.com/science/2018/11/strange-earthquake-waves-rippled-around-world-earth-geology/', 0, 'Strange waves rippled around the world, and nobody knows why', 'scintech', 0, '2018-11-29 09:56:26', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1895, 1, 'http://muaythaipros.com/top-10-muay-thai-fighters-of-all-time/', 0, 'TOP 10 MUAY THAI FIGHTERS OF ALL TIME', 'worldnhistory', 0, '2018-11-29 19:04:06', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1896, 1, 'https://www.blogto.com/toronto/the_best_martial_arts_in_toronto/', 0, 'The best martial arts gyms in Toronto', 'general', 0, '2018-12-01 13:38:23', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1897, 1, 'https://www.buzzfeednews.com/article/davidmack/rape-fraud-consent-purdue-abigail-finney-joyce-short-grant', 0, 'Rape By Fraud', 'worldnhistory', 0, '2018-12-03 04:04:28', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1898, 1, 'https://www.thebalancecareers.com/foreign-militaries-that-accept-us-citizens-2356537', 0, 'Learn Which Foreign Militaries Accept US Citizens', 'worldnhistory', 0, '2018-12-03 19:11:44', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1899, 1, 'https://www.newyorker.com/science/elements/the-neurons-that-tell-time?mbid=synd_digg', 0, 'The Neurons That Tell Time', 'scintech', 0, '2018-12-04 05:54:46', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1900, 1, 'https://www.quantamagazine.org/frauchiger-renner-paradox-clarifies-where-our-views-of-reality-go-wrong-20181203/', 0, 'New Quantum Paradox Clarifies Where Our Views of Reality Go Wrong', 'body', 0, '2018-12-04 05:55:31', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1901, 1, 'https://www.vice.com/en_us/article/gy7ypm/i-took-ayahuasca-at-a-countryside-retreat-and-it-was-as-profound-as-they-say-it-is-v25n4', 0, 'I Took Ayahuasca at a Countryside Retreat and It Was as Profound as They Say It Is', 'body', 0, '2018-12-04 05:56:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1902, 1, 'https://www.chiropractic-clinic.com.au/neck-exercises/', 0, 'Neck Exercises â€“ Stretches for Neck Pain', 'body', 0, '2018-12-05 05:02:48', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1903, 1, 'https://www.thisisinsider.com/craigslist-ad-killer-joseph-lopez-pleads-guilty-to-shooting-natalie-bollinger-2018-12?utm_source=quora&utm_medium=referral', 0, 'A man says a 19-year-old woman hired him to kill her on Craigslist, and alleges he tried to change her mind be', 'worldnhistory', 0, '2018-12-05 17:12:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1904, 1, 'https://www.vox.com/the-goods/2018/12/5/18119890/jewish-american-princess-jap-stereotype', 0, 'Reconsidering the Jewish American Princess', 'society', 0, '2018-12-06 01:21:01', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1905, 1, 'https://www.buzzfeednews.com/article/azeenghorayshi/neil-degrasse-tyson-sexual-allegations-four-women', 0, 'Nobody Believed Neil deGrasse Tyson\'s First Accuser. Now There Are Three More.', 'worldnhistory', 0, '2018-12-06 04:13:34', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1906, 1, 'https://www.nature.com/articles/d41586-018-07592-7', 0, 'The silent epidemic killing more people than HIV, malaria or TB', 'worldnhistory', 0, '2018-12-07 01:39:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1907, 1, 'https://www.nature.com/articles/d41586-018-07631-3', 0, 'Machine learning helps to hunt down the cause of a paralysing illness', 'scintech', 0, '2018-12-07 13:40:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1908, 1, 'https://www.youtube.com/watch?v=3Xpc0ny2xEI', 0, 'What happens to your body if you are stressed every day?', 'body', 0, '2018-12-10 11:31:41', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1909, 1, 'http://digg.com/2018/income-level-age-group-data-viz', 0, 'The Income Level Of Different Age Groups In The US, Visualized', 'worldnhistory', 0, '2018-12-10 12:00:58', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1910, 1, 'https://www.unifiedlawyers.com.au/blog/global-divorce-rates-statistics/', 0, 'Divorce Rate By Country', 'sexndating', 0, '2018-12-10 15:33:27', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1911, 1, 'https://qz.com/work/1481224/the-most-screwed-up-employee-perk-in-america-and-the-man-who-just-might-fix-it/', 0, 'The most screwed-up employee perk in America (and the man who just might fix it)', 'society', 0, '2018-12-10 18:48:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1912, 1, 'https://www.theatlantic.com/ideas/archive/2018/12/does-it-matter-where-you-go-college/577816/', 0, 'Does It Matter Where You Go to College?', 'worldnhistory', 0, '2018-12-12 13:59:20', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1913, 1, 'http://digg.com/video/slow-starter-wins-race', 0, 'Slowest Runner In A High School Race Dark-Horses Everyone', 'worldnhistory', 0, '2018-12-12 19:30:18', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1914, 1, 'https://www.cnn.com/2018/12/12/asia/canada-china-spavor-intl/index.html', 0, 'Second Canadian under investigation in China as diplomatic spat intensifies', 'worldnhistory', 0, '2018-12-13 15:04:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1915, 1, 'https://medium.com/@worstonlinedater/tinder-experiments-ii-guys-unless-you-are-really-hot-you-are-probably-better-off-not-wasting-your-2ddf370a6e9a', 0, 'Tinder Experiments II: Guys, unless you are really hot you are probably better off not wasting your time', 'sexndating', 0, '2018-12-14 04:51:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1916, 1, 'https://medium.com/@worstonlinedater/tinder-experiments-d44892e18f75', 0, 'Tinder Experiments', 'sexndating', 0, '2018-12-14 13:01:13', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1917, 1, 'https://melmagazine.com/en-us/story/why-some-men-cant-stop-compulsively-spending-on-women', 0, 'WHY SOME MEN CANâ€™T STOP COMPULSIVELY SPENDING MONEY ON WOMEN', 'sexndating', 0, '2018-12-14 13:19:38', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1918, 1, 'https://www.nytimes.com/2018/12/13/business/media/cbs-bull-weatherly-dushku-sexual-harassment.html', 0, 'CBS Paid the Actress Eliza Dushku $9.5 Million to Settle Harassment Claims', 'society', 0, '2018-12-14 13:24:30', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1919, 1, 'https://youtu.be/DxZVdAB5H8o', 0, '10 vs 1: Speed Dating 10 Girls Without Seeing Them', 'sexndating', 0, '2018-12-15 13:48:53', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1920, 1, 'https://www.nature.com/articles/d41586-018-07735-w', 0, 'â€˜Transmissibleâ€™ Alzheimerâ€™s theory gains traction', 'body', 0, '2018-12-16 03:46:07', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1921, 1, 'https://gizmodo.com/fbi-secretly-collected-data-on-aaron-swartz-earlier-tha-1831076900', 0, 'FBI Secretly Collected Data on Aaron Swartz Earlier Than We Thoughtâ€”in a Case Involving Al Qaeda', 'worldnhistory', 0, '2018-12-16 12:48:05', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1922, 1, 'https://qz.com/1496497/camille-herron-just-ran-the-worlds-fastest-24-hour-race/', 0, 'A woman just ran the worldâ€™s fastest 24-hour race', 'body', 0, '2018-12-16 13:48:32', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1923, 1, 'https://www.bbc.com/news/stories-46529582', 0, 'How a country suddenly went â€˜crazy richâ€™', 'worldnhistory', 0, '2018-12-17 14:28:51', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1924, 1, 'https://www.buzzfeednews.com/article/talalansari/this-tomb-in-egypt-is-4400-years-old-and-still-looks', 0, 'This 4,400-Year-Old Tomb Is In Great Condition And Officials In Egypt Are Stunned', 'worldnhistory', 0, '2018-12-17 18:00:21', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1925, 1, 'https://www.narcity.com/ca/on/toronto/things-to-do-in-to/you-can-learn-how-to-make-weed-edibles-at-cannabis-cooking-classes-in-toronto', 0, 'You Can Learn How To Make Weed Edibles At Cannabis Cooking Classes In Toronto', 'general', 0, '2018-12-19 00:03:36', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1926, 1, 'https://www.thedailybeast.com/making-a-murderer-cop-alleges-defamation-by-netflix', 0, 'â€˜Making a Murdererâ€™ Cop Alleges Defamation by Netflix', 'worldnhistory', 0, '2018-12-19 13:49:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1927, 1, 'https://motherboard.vice.com/en_us/article/3k9env/saturns-rings-are-disappearing-nasa-scientists-say', 0, 'Saturn\'s Rings Are Disappearing, NASA Scientists Say', 'scintech', 0, '2018-12-19 14:18:59', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1928, 1, 'https://medium.com/s/story/porn-is-becoming-taboo-again-a4d69d17d04b', 0, 'Porn Is Becoming Taboo Again', 'sexndating', 0, '2018-12-19 21:03:29', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1929, 1, 'https://www.businessnewsdaily.com/2919-unemployment-bias.html', 0, 'Looking for a Job? Don\'t Tell Them You\'re Unemployed', 'society', 0, '2018-12-23 23:02:24', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1930, 1, 'https://www.inc.com/john-rampton/reasons-you-could-get-fired-and-how-to-stop-it.html', 0, 'Reasons You Could Get Fired and How to Stop It', 'society', 0, '2018-12-24 01:19:22', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1931, 1, 'https://www.cnn.com/2018/12/25/health/thailand-medical-marijuana-bn/index.html', 0, 'Thailand approves medical marijuana', 'body', 0, '2018-12-26 00:32:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1932, 1, 'https://www.byrdie.com/average-cost-of-beauty-maintenance', 0, 'The Average Cost of Beauty Maintenance Could Put You Through Harvard', 'sexndating', 0, '2018-12-30 17:04:15', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1933, 1, 'https://evolve-vacation.com/blog/how-to-combat-a-heavy-puncher-in-muay-thai/', 0, 'How To Combat A Heavy Puncher In Muay Thai', 'general', 0, '2018-12-30 22:06:56', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1934, 1, 'https://www.youtube.com/watch?time_continue=697&v=HVk7koqlu1U', 0, '10 vs 1: Speed Dating 10 Guys Without Seeing Them', 'sexndating', 0, '2019-01-02 08:03:25', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1935, 1, 'https://www.vox.com/first-person/2019/1/2/18144979/doctor-racism-delta-airlines-dr-tamika-cross-fatima-cody-stanford', 0, 'The unchecked racism faced by physicians of color.', 'society', 0, '2019-01-03 13:37:50', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1936, 1, 'https://www.nytimes.com/2019/01/02/style/self-care/how-to-hold-healthy-grudges.html', 0, 'How to Hold Healthy Grudges', 'society', 0, '2019-01-03 13:38:54', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1937, 1, 'https://www.vice.com/en_us/article/qvqw3x/what-a-student-loan-bubble-bursting-might-look-like', 0, 'What a Student Loan \'Bubble\' Bursting Might Look Like', 'society', 0, '2019-01-03 16:14:45', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1938, 1, 'https://www.statnews.com/2019/01/03/charles-akoda-obgyn-fraud-patients/', 0, 'A shattering breach of trust: What happens to patients when their doctor is not who he claimed to be?', 'society', 0, '2019-01-03 16:29:37', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1939, 1, 'https://www.forbes.com/sites/lizryan/2017/04/14/never-trust-a-manager-who-does-these-five-things/#36fcca22d6f7', 0, 'Never Trust A Manager Who Does These Five Things', 'society', 0, '2019-01-08 20:21:03', '0000-00-00 00:00:00', 0, 0, 0, 29, 0),
(1940, 1, 'https://www.theparisreview.org/blog/2019/01/07/on-being-a-woman-in-america-while-trying-to-avoid-being-assaulted/', 0, 'On Being a Woman in America While Trying to Avoid Being Assaulted', 'worldnhistory', 0, '2019-01-08 20:41:33', '0000-00-00 00:00:00', 0, 0, 0, 29, 0);

-- --------------------------------------------------------

--
-- Table structure for table `articleunreviewed`
--

CREATE TABLE `articleunreviewed` (
  `aurid` bigint(20) NOT NULL,
  `title` varchar(200) DEFAULT NULL,
  `category` varchar(200) NOT NULL,
  `body` text,
  `link` varchar(500) DEFAULT NULL,
  `createdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `revisedate` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `status` int(11) NOT NULL DEFAULT '0',
  `type` int(11) NOT NULL,
  `creatorid` varchar(45) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `articleunreviewed`
--

INSERT INTO `articleunreviewed` (`aurid`, `title`, `category`, `body`, `link`, `createdate`, `revisedate`, `status`, `type`, `creatorid`) VALUES
(1, 'Sub $100 3D Printer', 'scintech', NULL, 'http://www.kickstarter.com/projects/117421627/the-peachy-printer-the-first-100-3d-printer-and-sc', '2013-09-28 15:16:14', '0000-00-00 00:00:00', 2, 1, '29'),
(2, '8 Reasons Straight Men Don\'t Want To Get Married', 'sexndating', NULL, 'http://www.huffingtonpost.com/helen-smith/8-reasons-men-dont-want-t_b_3467778.html', '2013-09-28 16:08:18', '0000-00-00 00:00:00', 2, 1, '29'),
(3, 'Life is not fair', 'society', NULL, 'http://www.patheos.com/blogs/inspiration/2013/04/life-is-not-fair/', '2013-09-30 15:55:32', '0000-00-00 00:00:00', 2, 1, '29'),
(4, 'Dick Costolo Just Called This Critic Of His All-Male, All-White Board \'The Carrot Top Of Academic Sources\' ', 'society', NULL, 'http://www.businessinsider.com/dick-costolo-just-called-this-critic-of-his-all-male-all-white-board-the-carrot-top-of-academic-sources-2013-10', '2013-10-10 00:51:33', '0000-00-00 00:00:00', 2, 1, '29'),
(5, 'Who wants to be a Russian billionaire?', 'society', NULL, 'http://blogs.wsj.com/emergingeurope/2013/10/09/who-wants-to-be-a-russian-billionaire/', '2013-10-10 00:51:35', '0000-00-00 00:00:00', 2, 1, '29'),
(6, 'Looks like there may be a happy marriage gene', 'scintech', NULL, 'http://www.nerve.com/love-sex/oof-it-looks-like-theres-a-happy-marriage-gene', '2013-10-10 00:51:36', '0000-00-00 00:00:00', 2, 1, '29'),
(7, 'Lock Picking - A Basic Guide', 'scintech', NULL, 'https://www.hackthis.co.uk/articles/picking-locks-a-basic-guide', '2014-01-06 12:13:47', '0000-00-00 00:00:00', 2, 1, '29'),
(8, 'PM Yingluck Shinawatra ploughs on despite calls for her to stand down ', 'society', NULL, 'http://www.independent.co.uk/news/world/asia/thailand-protests-pm-yingluck-shinawatra-ploughs-on-despite-calls-for-her-to-stand-down-after-disputed-election-9117082.html', '2014-02-09 00:49:16', '0000-00-00 00:00:00', 2, 1, '85'),
(9, 'Astronauts Simulate Deep-Space Mission in Underwater Lab For 8 Days', 'scintech', NULL, 'http://www.space.com/26635-underwater-neemo-18-mission.html', '2014-07-28 00:50:01', '0000-00-00 00:00:00', 2, 1, '29'),
(10, 'U.S: Satellite Imagery Shows Russians Shelling Eastern Ukraine', 'worldnhistory', NULL, 'http://time.com/3042640/satellite-russian-ukraine-shelling/', '2014-07-29 12:00:21', '0000-00-00 00:00:00', 2, 1, '29'),
(11, 'Did the Chicago police coerce witnesses into pinpointing the wrong man for murder?', 'society', NULL, 'http://www.newyorker.com/magazine/2014/08/04/crime-fiction', '2014-07-29 12:00:16', '0000-00-00 00:00:00', 2, 1, '29'),
(12, 'Why are some people so much luckier than others?', 'society', NULL, 'http://ninjasandrobots.com/why-are-some-people-so-much-luckier-than-others', '2014-07-30 03:19:32', '0000-00-00 00:00:00', 2, 1, '29'),
(13, 'How Black People Are Portrayed in Mainstream Media', 'society', NULL, 'http://www.theroot.com/blogs/the_grapevine/2014/08/_iftheygunnedmedown_shows_how_black_people_are_portrayed_in_mainstream_media.html', '2014-08-12 10:50:20', '0000-00-00 00:00:00', 2, 1, '29'),
(14, 'Charles Manson\'s wife', 'society', NULL, 'http://www.cnn.com/2014/08/09/justice/charles-manson-wife', '2014-08-12 10:50:21', '0000-00-00 00:00:00', 2, 1, '29'),
(15, 'Secret Polish Army', 'worldnhistory', NULL, 'http://boingboing.net/2014/08/15/inside-job.html', '2014-08-16 23:26:24', '0000-00-00 00:00:00', 2, 1, '29'),
(16, 'Harper government reduces employment equity requirements for contractors', 'society', NULL, 'http://www.ipolitics.ca/2013/06/28/harper-government-reduces-employment-equity-requirements-for-contractors/', '2014-09-30 04:52:28', '0000-00-00 00:00:00', 2, 1, '29'),
(17, 'Aids: Origin of pandemic \'was 1920s Kinshasa\'', 'scintech', NULL, 'http://www.bbc.com/news/health-29442642', '2014-11-10 09:44:30', '0000-00-00 00:00:00', 2, 1, '29'),
(18, 'I am in a wheelchair & i don\'t want to go out no more, why do people laugh at people less fortunate than them?', 'society', NULL, 'https://uk.answers.yahoo.com/question/index?qid=20080517151222AAvoP6P', '2014-11-10 09:44:13', '0000-00-00 00:00:00', 2, 1, '29'),
(19, 'ISIS leader says group will mint its own coins', 'worldnhistory', NULL, 'http://www.bostonglobe.com/news/world/2014/11/14/isis-leader-says-group-will-mint-its-own-coins/kaOYWSlRA58MthSC1osA7M/story.html', '2015-02-15 04:07:02', '0000-00-00 00:00:00', 2, 1, '29');

-- --------------------------------------------------------

--
-- Table structure for table `comments`
--

CREATE TABLE `comments` (
  `cid` bigint(20) NOT NULL,
  `pcid` bigint(20) DEFAULT NULL,
  `linkid` bigint(20) NOT NULL,
  `body` varchar(2000) DEFAULT NULL,
  `createdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `revisedate` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `creatorid` bigint(20) DEFAULT NULL,
  `haschild` bit(1) NOT NULL DEFAULT b'0'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `comments`
--

INSERT INTO `comments` (`cid`, `pcid`, `linkid`, `body`, `createdate`, `revisedate`, `creatorid`, `haschild`) VALUES
(11, 0, 2, 'I\'m betting it is real.', '2013-07-29 01:37:59', '0000-00-00 00:00:00', 29, b'0'),
(12, 0, 48, 'I was raped and I responded similarly. I trusted him and really didn\'t want to cause trouble because even in the aftermath I wanted to be friends with him. I doubt anyone would have believe me anyways', '2013-07-31 05:17:01', '0000-00-00 00:00:00', 82, b'0'),
(13, 0, 44, 'God damn nit. I wish that employers actually gave a damn about loyalty and not profits. They want your loyalty, but aren\'t going to be loyal to you.', '2013-07-31 07:10:01', '0000-00-00 00:00:00', 80, b'0'),
(14, 0, 216, 'hi', '2013-09-26 03:46:05', '0000-00-00 00:00:00', 29, b'0'),
(15, 0, 235, 'I KNEW IT!', '2013-11-02 13:03:59', '0000-00-00 00:00:00', 29, b'0'),
(16, 0, 306, 'Yes we can! LOL :)', '2013-12-20 04:09:43', '0000-00-00 00:00:00', 29, b'0'),
(17, 0, 353, 'nTo enjoy the fruit of life, you have to let go the pains of the past. In history humanity committed a lot of atrocities. Hanging on to past only increases the pain. Let go the past you evolve and MAK', '2014-02-11 01:54:29', '0000-00-00 00:00:00', 83, b'0'),
(18, 0, 353, 'nTo enjoy the fruit of life, you have to let go the pains of the past. In history humanity committed a lot of atrocities. Hanging on to past only increases the pain. Let go the past you evolve and MAK', '2014-02-11 01:55:18', '0000-00-00 00:00:00', 83, b'0'),
(19, 0, 691, 'Finally. Why are these groups allowed to exist considering their history of violence and hate? The very name of the group reeks of terrorism and injustice. The fact that they haven\'t changed their nam', '2015-11-01 03:47:41', '0000-00-00 00:00:00', 29, b'0'),
(20, 0, 1201, 'Very few things are as corny as that joke ...', '2017-12-08 17:41:38', '0000-00-00 00:00:00', 29, b'0'),
(21, 0, 1201, 'I don\'t think it is a corny joke. It is quite clever, actually.', '2017-12-08 19:02:52', '0000-00-00 00:00:00', 87, b'0');

-- --------------------------------------------------------

--
-- Table structure for table `dictionary`
--

CREATE TABLE `dictionary` (
  `dictionaryid` bigint(20) NOT NULL,
  `tbl` varchar(200) DEFAULT NULL,
  `col` varchar(200) DEFAULT NULL,
  `val` varchar(200) DEFAULT NULL,
  `realval` varchar(200) DEFAULT NULL,
  `details` varchar(2000) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `dictionary`
--

INSERT INTO `dictionary` (`dictionaryid`, `tbl`, `col`, `val`, `realval`, `details`) VALUES
(1, 'all', 'careerLvl', '12', 'Experienced (Non-Manager)', 'This number represents a career level of Experienced (Non-Manager)'),
(2, 'all', 'careerLvl', '9', 'Student (High School)', 'This number represents a career level of Student (High School)'),
(3, 'all', 'careerLvl', '10', 'Student', 'This number represents a career level of Student'),
(4, 'all', 'careerLvl', '11', 'Entry Level', 'This number represents a career level of Entry Level'),
(5, 'all', 'careerLvl', '13', 'Manager (Manager/Supervisor of Staff)', 'This number represents a career level of Manager (Manager/Supervisor of Staff)'),
(6, 'all', 'careerLvl', '14', 'Executive (SVP, VP, Department Head, etc.)', 'This number represents a career level of Executive (SVP, VP, Department Head, etc.)'),
(7, 'all', 'careerLvl', '15', 'Senior Executive (President, CFO)', 'This number represents a career level of Senior Executive (President, CFO)'),
(8, 'all', 'education', '0', 'Some High School Coursework', 'This number indicates you didn\'t finish highschool.'),
(9, 'all', 'education', '1', 'High School or equivalent', 'This number indicates you finished highschool.'),
(10, 'all', 'education', '2', 'Certification', 'This number indicates you got certification in something.'),
(11, 'all', 'education', '3', 'Vocational', 'This number indicates you got a vocational degree.'),
(12, 'all', 'education', '4', 'Some College Coursework Completed', 'This number indicates you finished some college coursework.'),
(13, 'all', 'education', '5', 'College Diploma', 'This number indicates you have a college diploma.'),
(14, 'all', 'education', '6', 'Bachelor\'s Degree', 'This number indicates you have a bachelor\'s degree.'),
(15, 'all', 'education', '7', 'Master\'s Degree', 'This number indicates you have a masters degree.'),
(16, 'all', 'education', '8', 'Doctorate', 'This number indicates you have a doctorate degree.'),
(17, 'all', 'education', '9', 'Professional', 'This number indicates you have a professional degree.'),
(18, 'all', 'education', '-1', 'None Selected', 'This number indicates you have not selected any education.'),
(19, 'all', 'state', 'DC', 'District Of Columbia', 'This code is for a state in the USA'),
(20, 'all', 'state', 'WA', 'Washington', 'This code is for a state in the USA'),
(21, 'all', 'state', 'CA', 'California', 'This code is for a state in the USA'),
(23, 'all', 'state', 'NY', 'New York', 'This code is for a state in the USA'),
(24, 'all', 'state', 'GA', 'Georgia', 'This code is for a state in the USA'),
(25, 'all', 'state', 'NC', 'North Carolina', 'This code is for a state in the USA'),
(26, 'all', 'state', 'FL', 'Florida', 'This code is for a state in the USA'),
(27, 'all', 'state', 'TX', 'Texas', 'This code is for a state in the USA'),
(28, 'all', 'state', 'MA', 'Massachusetts', 'This code is for a state in the USA'),
(29, 'all', 'state', 'MI', 'Michigan', 'This code is for a state in the USA'),
(30, 'all', 'state', 'MN', 'Minnesota', 'This code is for a state in the USA'),
(31, 'all', 'state', 'MS', 'Mississippi', 'This code is for a state in the USA'),
(32, 'all', 'state', 'MO', 'Missouri', 'This code is for a state in the USA'),
(33, 'all', 'state', 'MT', 'Montana', 'This code is for a state in the USA'),
(34, 'all', 'state', 'NE', 'Nebraska', 'This code is for a state in the USA'),
(35, 'all', 'state', 'NV', 'Nevada', 'This code is for a state in the USA'),
(36, 'all', 'state', 'NH', 'New Hampshire', 'This code is for a state in the USA'),
(37, 'all', 'state', 'NM', 'New Mexico', 'This code is for a state in the USA'),
(38, 'all', 'state', 'ND', 'North Dakota', 'This code is for a state in the USA'),
(39, 'all', 'state', 'OH', 'Ohio', 'This code is for a state in the USA'),
(40, 'all', 'state', 'OK', 'Oklahoma', 'This code is for a state in the USA'),
(41, 'all', 'state', 'OR', 'Oregon', 'This code is for a state in the USA'),
(42, 'all', 'state', 'PA', 'Pennsylvania', 'This code is for a state in the USA'),
(43, 'all', 'state', 'RI', 'Rhode Island', 'This code is for a state in the USA'),
(44, 'all', 'state', 'SC', 'South Carolina', 'This code is for a state in the USA'),
(45, 'all', 'state', 'SD', 'South Dakota', 'This code is for a state in the USA'),
(46, 'all', 'state', 'TN', 'Tennessee', 'This code is for a state in the USA'),
(47, 'all', 'state', 'UT', 'Utah', 'This code is for a state in the USA'),
(48, 'all', 'state', 'VT', 'Vermont', 'This code is for a state in the USA'),
(49, 'all', 'state', 'VA', 'Virginia', 'This code is for a state in the USA'),
(50, 'all', 'state', 'WV', 'West Virginia', 'This code is for a state in the USA'),
(51, 'all', 'state', 'WI', 'Wisconsin', 'This code is for a state in the USA'),
(52, 'all', 'state', 'WY', 'Wyoming', 'This code is for a state in the USA'),
(53, 'all', 'state', 'MD', 'Maryland', 'This code is for a state in the USA'),
(54, 'all', 'state', 'ME', 'Maine', 'This code is for a state in the USA'),
(55, 'all', 'state', 'LA', 'Louisiana', 'This code is for a state in the USA'),
(56, 'all', 'state', 'KY', 'Kentucky', 'This code is for a state in the USA'),
(57, 'all', 'state', 'KS', 'Kansas', 'This code is for a state in the USA'),
(58, 'all', 'state', 'IA', 'Iowa', 'This code is for a state in the USA'),
(59, 'all', 'state', 'IN', 'Indiana', 'This code is for a state in the USA'),
(60, 'all', 'state', 'IL', 'Illinois', 'This code is for a state in the USA'),
(61, 'all', 'state', 'ID', 'Idaho', 'This code is for a state in the USA'),
(62, 'all', 'state', 'HI', 'Hawaii', 'This code is for a state in the USA'),
(63, 'all', 'state', 'DE', 'Delaware', 'This code is for a state in the USA'),
(64, 'all', 'state', 'CT', 'Connecticut', 'This code is for a state in the USA'),
(65, 'all', 'state', 'CO', 'Colorado', 'This code is for a state in the USA'),
(66, 'all', 'state', 'AR', 'Arkansas', 'This code is for a state in the USA'),
(67, 'all', 'state', 'AZ', 'Arizona', 'This code is for a state in the USA'),
(68, 'all', 'state', 'AK', 'Alaska', 'This code is for a state in the USA'),
(69, 'all', 'state', 'AL', 'Alabama', 'This code is for a state in the USA'),
(70, 'all', 'province', 'ON', 'Ontario', 'This code is for a province in Canada'),
(71, 'all', 'province', 'BC', 'British Columbia', 'This code is for a province in Canada'),
(72, 'all', 'province', 'NS', 'Nova Scotia', 'This code is for a province in Canada'),
(73, 'all', 'province', 'AB', 'Alberta', 'This code is for a province in Canada'),
(74, 'all', 'province', 'MB', 'Manitoba', 'This code is for a province in Canada'),
(75, 'all', 'province', 'NB', 'New Brunswick', 'This code is for a province in Canada'),
(76, 'all', 'province', 'NL', 'Newfoundland and Labrador', 'This code is for a province in Canada'),
(77, 'all', 'province', 'NT', 'Northwest Territories', 'This code is for a province in Canada'),
(78, 'all', 'province', 'NU', 'Nunavut', 'This code is for a province in Canada'),
(79, 'all', 'province', 'PE', 'Prince Edward Island', 'This code is for a province in Canada'),
(80, 'all', 'province', 'QC', 'Quebec', 'This code is for a province in Canada'),
(81, 'all', 'province', 'SK', 'Saskatchewan', 'This code is for a province in Canada'),
(82, 'all', 'province', 'YT', 'Yukon', 'This code is for a province in Canada'),
(83, 'normal', 'country', '1', 'Canada', 'This is the full name for a country'),
(84, 'all', 'country', '2', 'United States Of America', 'This is the full name for a country'),
(85, 'all', 'country', '1', 'CA', 'This is the short hand for a country'),
(86, 'all', 'country', '2', 'usa', 'This is the short hand for a country'),
(87, 'normal', 'country', '2', 'United States', 'This is the full name for a country'),
(88, 'all', 'country', '2', 'us', 'This is the short hand for a country'),
(89, 'all', 'careerLvl', '-1', 'None Selected', NULL),
(90, 'all', 'education', '-1', 'None Selected', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `location`
--

CREATE TABLE `location` (
  `lid` bigint(20) NOT NULL,
  `country` varchar(200) DEFAULT NULL,
  `region` varchar(200) DEFAULT NULL,
  `city` varchar(200) DEFAULT NULL,
  `address1` varchar(200) DEFAULT NULL,
  `address2` varchar(200) DEFAULT NULL,
  `address3` varchar(200) DEFAULT NULL,
  `postalCode` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `location`
--

INSERT INTO `location` (`lid`, `country`, `region`, `city`, `address1`, `address2`, `address3`, `postalCode`) VALUES
(106, '1', 'mb', 'list', '', '', '', 'j3j-3j3'),
(107, '1', 'ab', 'edmonton', '', '', '', 'j8j-2s2'),
(108, '2', 'al', 'town', '', '', '', '90210'),
(109, '2', 'ca', 'poway', '', '', '', '90210'),
(110, '2', 'az', 'thailand', '', '', '', '23233'),
(111, '1', 'on', 'toronto', '', '', '', 'j3r-2w2'),
(112, '1', 'on', 'toronto', '', '', '', 'm6h-3v1'),
(113, '1', 'on', 'bram', '', '', '', 'l7a-2k3'),
(114, '1', 'select province', 'brampton', '', '', '', 'l7a-2k4'),
(115, '1', 'on', 'toronto', '', '', '', 'l7a-3d3'),
(116, '1', 'on', 'scarborough', '', '', '', 'm1k-5j8');

-- --------------------------------------------------------

--
-- Table structure for table `log`
--

CREATE TABLE `log` (
  `log` longtext
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `message`
--

CREATE TABLE `message` (
  `mid` bigint(20) NOT NULL,
  `uid` bigint(20) NOT NULL,
  `title` varchar(200) NOT NULL,
  `message` varchar(2000) NOT NULL,
  `createdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `revisedate` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `messageexchange`
--

CREATE TABLE `messageexchange` (
  `meid` bigint(20) NOT NULL,
  `senderuid` bigint(20) NOT NULL,
  `recieveruid` bigint(20) NOT NULL,
  `title` varchar(200) NOT NULL,
  `message` varchar(2000) NOT NULL,
  `appendcontactinfo` tinyint(1) NOT NULL DEFAULT '1',
  `createdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `viewed` tinyint(4) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Table structure for table `session`
--

CREATE TABLE `session` (
  `sid` bigint(20) NOT NULL,
  `uid` bigint(20) DEFAULT NULL,
  `sessionid` varchar(500) DEFAULT NULL,
  `ipaddress` varchar(16) DEFAULT NULL,
  `passcode` varchar(500) DEFAULT NULL,
  `createdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `destroydate` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Dumping data for table `session`
--

INSERT INTO `session` (`sid`, `uid`, `sessionid`, `ipaddress`, `passcode`, `createdate`, `destroydate`) VALUES
(658, 86, 'rfbjl5tni50sasn8ov2mhv73q2', '99.245.44.27', '7eba22fa9e5e9e943c40d5ecabf3bcc5', '2014-07-17 01:22:52', '0000-00-00 00:00:00'),
(1510, 29, '31asnt8psed8345q99hf9ore56', '174.117.22.174', '41c624da2be4b223158496098f6b567c', '2019-01-08 20:20:35', '0000-00-00 00:00:00');

-- --------------------------------------------------------

--
-- Table structure for table `userinformation`
--

CREATE TABLE `userinformation` (
  `uiid` bigint(20) NOT NULL,
  `uid` bigint(20) DEFAULT NULL,
  `firstName` varchar(200) DEFAULT NULL,
  `lastName` varchar(200) DEFAULT NULL,
  `careerLvl` varchar(200) DEFAULT NULL,
  `lid` bigint(20) DEFAULT NULL,
  `education` varchar(200) DEFAULT NULL,
  `phone1` varchar(20) DEFAULT NULL,
  `phone2` varchar(20) DEFAULT NULL,
  `phone3` varchar(20) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Dumping data for table `userinformation`
--

INSERT INTO `userinformation` (`uiid`, `uid`, `firstName`, `lastName`, `careerLvl`, `lid`, `education`, `phone1`, `phone2`, `phone3`) VALUES
(29, 3, 'Carlos', 'Santana', '13', 3, '0', NULL, NULL, NULL),
(30, 4, 'n', 'j', '15', 32, '8', NULL, NULL, NULL),
(60, 83, 'krishna', 'Thinduvalanthan', '', 112, '', '(716) 282-3444 x____', NULL, NULL),
(64, 87, 'Neel', 'J2', '', 116, '', '(905) 455-9760 x____', NULL, NULL),
(65, 29, 'Neel', 'J', '', 116, '', '(905) 455-9761 x____', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `uid` bigint(20) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password` char(64) NOT NULL,
  `salt` char(64) NOT NULL,
  `status` int(11) DEFAULT NULL,
  `accounttype` int(11) NOT NULL DEFAULT '0',
  `lastlogindate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`uid`, `email`, `password`, `salt`, `status`, `accounttype`, `lastlogindate`) VALUES
(29, 'neelj@yahoo.ca', '422e596c9f27399c96c86d7f841e5b8bb33', '4470', 1, 3, '2019-01-08 20:20:34'),
(30, 'antoinette@gmail.com', '5ceb0b1d81a34cb76bf509cb49750f6e5e21', '5597', 1, 1, '0000-00-00 00:00:00'),
(83, 'krish@gmail.com', '037796d4654bdc31c45561c64a2a90fe005', '2762', 1, 1, '2014-02-24 02:19:39'),
(87, 'neela@gmail.com', 'fa7aa0dd28487b73bc7dc8e0194392966ff', '3514', 1, 1, '2017-12-08 19:02:28');

-- --------------------------------------------------------

--
-- Table structure for table `verificationcodes`
--

CREATE TABLE `verificationcodes` (
  `uid` bigint(20) NOT NULL,
  `verificationcode` varchar(200) NOT NULL,
  `type` bigint(20) NOT NULL DEFAULT '0',
  `createdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `verificationcodes`
--

INSERT INTO `verificationcodes` (`uid`, `verificationcode`, `type`, `createdate`) VALUES
(83, '2579ef5011', 1, '2017-04-14 12:47:23');

-- --------------------------------------------------------

--
-- Table structure for table `visitortracker`
--

CREATE TABLE `visitortracker` (
  `ipaddress` varchar(300) NOT NULL,
  `visitdate` date NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `visitortracker`
--

INSERT INTO `visitortracker` (`ipaddress`, `visitdate`) VALUES
('108.168.105.221', '2017-07-31'),
('167.114.209.38', '2017-07-31'),
('104.145.12.30', '2017-07-31'),
('157.52.19.210', '2017-07-31'),
('66.249.66.92', '2017-08-01'),
('40.77.167.131', '2017-08-01'),
('157.52.19.210', '2017-08-01'),
('108.168.105.221', '2017-08-01'),
('66.249.66.208', '2017-08-01'),
('108.168.105.221', '2017-08-02'),
('104.145.12.30', '2017-08-02'),
('188.32.236.102', '2017-08-02'),
('176.193.115.233', '2017-08-02'),
('118.140.38.3', '2017-08-03'),
('213.180.203.36', '2017-08-03'),
('109.63.184.153', '2017-08-03'),
('34.207.73.74', '2017-08-03'),
('104.236.62.28', '2017-08-10'),
('108.168.105.221', '2017-09-29'),
('108.168.105.221', '2017-09-30'),
('66.220.145.148', '2017-09-30'),
('144.121.160.88', '2017-10-06'),
('64.74.215.178', '2017-10-06'),
('158.69.26.193', '2017-10-06'),
('64.74.215.131', '2017-10-07'),
('64.74.215.178', '2017-10-07'),
('70.42.131.170', '2017-10-07'),
('108.168.105.221', '2017-10-08'),
('64.74.215.166', '2017-10-08'),
('64.74.215.131', '2017-10-09'),
('104.145.12.30', '2017-10-11'),
('104.145.12.30', '2017-10-12'),
('104.145.12.30', '2017-10-24'),
('104.145.12.30', '2017-10-27'),
('167.114.174.95', '2017-11-02'),
('108.168.105.221', '2017-11-05'),
('108.168.105.221', '2017-11-09'),
('108.168.105.221', '2017-11-10'),
('108.168.105.221', '2017-11-12'),
('108.168.105.221', '2017-11-16'),
('104.145.12.30', '2017-11-20'),
('108.168.105.221', '2017-11-24'),
('108.168.105.221', '2017-11-25'),
('66.249.64.153', '2017-11-26'),
('66.249.64.155', '2017-11-26'),
('66.249.64.23', '2017-11-26'),
('108.168.105.221', '2017-11-27'),
('108.168.105.221', '2017-11-29'),
('66.249.64.23', '2017-11-29'),
('108.168.105.221', '2017-11-30'),
('66.249.64.25', '2017-12-01'),
('108.168.105.221', '2017-12-02'),
('108.168.105.221', '2017-12-03'),
('108.168.105.221', '2017-12-04'),
('108.168.105.221', '2017-12-06'),
('66.249.64.23', '2017-12-07'),
('66.249.64.153', '2017-12-07'),
('207.46.13.60', '2017-12-07'),
('108.168.105.221', '2017-12-08'),
('108.168.105.221', '2017-12-09'),
('108.168.105.221', '2017-12-10'),
('108.168.105.221', '2017-12-11'),
('108.168.105.221', '2017-12-16'),
('108.168.105.221', '2017-12-17'),
('108.168.105.221', '2017-12-18'),
('108.168.105.221', '2017-12-19'),
('108.168.105.221', '2017-12-20'),
('108.168.105.221', '2017-12-23'),
('108.168.105.221', '2017-12-25'),
('108.168.105.221', '2017-12-26'),
('108.168.105.221', '2017-12-27'),
('66.249.64.23', '2017-12-27'),
('66.249.64.153', '2017-12-28'),
('66.249.64.23', '2017-12-28'),
('108.168.105.221', '2017-12-28'),
('205.189.187.4', '2017-12-30'),
('108.168.105.221', '2017-12-31'),
('108.168.105.221', '2018-01-02'),
('108.168.105.221', '2018-01-03'),
('108.168.105.221', '2018-01-04'),
('108.168.105.221', '2018-01-05'),
('108.168.105.221', '2018-01-06'),
('158.69.225.36', '2018-01-06'),
('108.168.105.221', '2018-01-07'),
('108.168.105.221', '2018-01-08'),
('104.151.24.105', '2018-01-08'),
('108.168.105.221', '2018-01-09'),
('108.168.105.221', '2018-01-10'),
('40.77.167.60', '2018-01-10'),
('108.168.105.221', '2018-01-11'),
('40.77.167.43', '2018-01-12'),
('108.168.105.221', '2018-01-12'),
('108.168.105.221', '2018-01-14'),
('206.47.9.222', '2018-01-16'),
('69.58.178.59', '2018-01-16'),
('108.168.105.221', '2018-01-17'),
('206.47.9.222', '2018-01-17'),
('188.226.196.155', '2018-01-18'),
('108.168.105.221', '2018-01-20'),
('108.168.105.221', '2018-01-21'),
('206.47.9.222', '2018-01-23'),
('108.168.105.221', '2018-01-24'),
('46.147.215.44', '2018-01-25'),
('108.168.105.221', '2018-01-25'),
('195.91.224.113', '2018-01-25'),
('195.91.224.113', '2018-01-26'),
('108.168.105.221', '2018-01-26'),
('109.63.141.89', '2018-01-26'),
('206.47.9.222', '2018-01-26'),
('95.220.194.206', '2018-01-26'),
('78.106.119.52', '2018-01-26'),
('109.173.25.162', '2018-01-26'),
('109.63.143.113', '2018-01-27'),
('108.168.105.221', '2018-01-27'),
('5.228.129.60', '2018-01-27'),
('188.32.6.92', '2018-01-27'),
('95.221.253.117', '2018-01-28'),
('108.168.105.221', '2018-01-28'),
('128.69.227.136', '2018-01-28'),
('37.204.181.186', '2018-01-28'),
('95.220.206.105', '2018-01-29'),
('128.68.143.180', '2018-01-29'),
('157.55.39.226', '2018-01-29'),
('37.110.51.73', '2018-01-29'),
('95.221.212.62', '2018-01-30'),
('109.173.58.115', '2018-01-30'),
('206.47.9.222', '2018-01-30'),
('46.42.132.107', '2018-01-30'),
('188.32.41.137', '2018-01-31'),
('128.69.232.58', '2018-01-31'),
('95.221.229.149', '2018-01-31'),
('206.47.9.222', '2018-01-31'),
('157.55.39.66', '2018-01-31'),
('108.168.105.221', '2018-01-31'),
('95.221.235.14', '2018-02-01'),
('108.168.105.221', '2018-02-01'),
('206.47.9.222', '2018-02-01'),
('90.154.93.19', '2018-02-01'),
('176.14.207.97', '2018-02-01'),
('95.27.128.23', '2018-02-02'),
('89.178.91.242', '2018-02-02'),
('37.204.52.249', '2018-02-03'),
('5.164.123.200', '2018-02-03'),
('108.168.105.221', '2018-02-03'),
('176.15.199.194', '2018-02-03'),
('128.72.228.99', '2018-02-04'),
('95.27.79.32', '2018-02-04'),
('37.204.153.61', '2018-02-04'),
('128.75.93.225', '2018-02-05'),
('89.178.225.19', '2018-02-05'),
('206.47.9.222', '2018-02-05'),
('85.91.197.133', '2018-02-05'),
('95.221.213.230', '2018-02-06'),
('206.47.9.222', '2018-02-06'),
('5.166.236.104', '2018-02-06'),
('27.152.73.47', '2018-02-06'),
('90.154.68.212', '2018-02-07'),
('128.74.247.114', '2018-02-08'),
('188.32.6.49', '2018-02-08'),
('66.249.64.72', '2018-02-08'),
('82.145.46.102', '2018-02-08'),
('46.242.7.253', '2018-02-09'),
('167.114.172.223', '2018-02-09'),
('213.180.203.2', '2018-02-10'),
('37.204.191.73', '2018-02-10'),
('46.42.150.217', '2018-02-10'),
('5.228.24.186', '2018-02-10'),
('93.80.36.249', '2018-02-10'),
('95.27.253.171', '2018-02-10'),
('5.166.232.231', '2018-02-11'),
('46.188.22.189', '2018-02-11'),
('5.228.129.95', '2018-02-11'),
('128.69.209.208', '2018-02-11'),
('206.47.9.222', '2018-02-12'),
('108.168.105.221', '2018-02-13'),
('206.47.9.222', '2018-02-13'),
('94.180.165.32', '2018-02-13'),
('77.37.220.101', '2018-02-13'),
('95.24.7.160', '2018-02-13'),
('128.69.150.180', '2018-02-13'),
('128.72.238.165', '2018-02-14'),
('206.47.9.222', '2018-02-14'),
('108.168.105.221', '2018-02-14'),
('108.168.105.221', '2018-02-15'),
('93.80.36.249', '2018-02-15'),
('95.24.8.158', '2018-02-15'),
('206.47.9.222', '2018-02-15'),
('95.28.173.8', '2018-02-15'),
('40.77.167.176', '2018-02-15'),
('108.168.105.221', '2018-02-16'),
('206.47.9.222', '2018-02-16'),
('94.180.160.238', '2018-02-16'),
('37.204.28.254', '2018-02-16'),
('95.28.36.166', '2018-02-17'),
('108.168.105.221', '2018-02-17'),
('157.55.39.59', '2018-02-17'),
('93.80.36.247', '2018-02-18'),
('108.168.105.221', '2018-02-18'),
('180.76.15.20', '2018-02-18'),
('5.16.88.190', '2018-02-18'),
('46.242.72.2', '2018-02-18'),
('37.145.124.191', '2018-02-18'),
('95.28.167.99', '2018-02-18'),
('220.181.132.198', '2018-02-18'),
('5.228.149.65', '2018-02-19'),
('95.28.178.29', '2018-02-19'),
('109.63.190.253', '2018-02-19'),
('206.47.9.222', '2018-02-20'),
('95.24.30.7', '2018-02-20'),
('108.168.105.221', '2018-02-20'),
('176.193.123.204', '2018-02-20'),
('5.3.156.190', '2018-02-21'),
('108.168.105.221', '2018-02-21'),
('46.147.99.95', '2018-02-21'),
('206.47.9.222', '2018-02-21'),
('5.228.129.60', '2018-02-21'),
('66.249.66.95', '2018-02-21'),
('128.72.37.124', '2018-02-21'),
('85.30.249.9', '2018-02-21'),
('46.42.131.51', '2018-02-22'),
('95.27.46.223', '2018-02-22'),
('69.58.178.56', '2018-02-22'),
('108.168.105.221', '2018-02-22'),
('128.72.177.9', '2018-02-22'),
('128.72.208.125', '2018-02-23'),
('176.99.234.194', '2018-02-23'),
('37.145.30.147', '2018-02-24'),
('37.144.86.233', '2018-02-24'),
('95.220.192.193', '2018-02-24'),
('108.168.105.221', '2018-02-24'),
('188.32.179.183', '2018-02-25'),
('128.72.238.165', '2018-02-25'),
('108.168.105.221', '2018-02-25'),
('46.188.52.168', '2018-02-25'),
('37.110.51.73', '2018-02-25'),
('176.192.165.172', '2018-02-25'),
('206.47.9.222', '2018-02-26'),
('95.28.190.43', '2018-02-26'),
('89.178.238.219', '2018-02-26'),
('108.168.105.221', '2018-02-27'),
('89.178.225.19', '2018-02-27'),
('5.228.38.226', '2018-02-27'),
('188.255.17.200', '2018-02-27'),
('176.214.15.179', '2018-02-28'),
('93.80.229.29', '2018-02-28'),
('128.72.234.70', '2018-02-28'),
('206.47.9.222', '2018-02-28'),
('40.77.167.65', '2018-02-28'),
('128.72.208.183', '2018-03-01'),
('128.72.218.129', '2018-03-02'),
('174.117.22.174', '2018-03-02'),
('46.188.22.189', '2018-03-02'),
('206.47.9.222', '2018-03-02'),
('183.11.71.150', '2018-03-02'),
('176.14.246.30', '2018-03-02'),
('5.228.95.146', '2018-03-03'),
('128.72.225.101', '2018-03-03'),
('101.199.112.49', '2018-03-04'),
('95.24.133.206', '2018-03-04'),
('128.204.14.126', '2018-03-04'),
('174.117.22.174', '2018-03-04'),
('206.47.9.222', '2018-03-05'),
('5.164.102.158', '2018-03-05'),
('178.140.86.41', '2018-03-05'),
('174.117.22.174', '2018-03-05'),
('176.14.9.250', '2018-03-05'),
('176.14.201.138', '2018-03-06'),
('206.47.9.222', '2018-03-06'),
('109.63.187.218', '2018-03-06'),
('95.28.16.10', '2018-03-06'),
('174.117.22.174', '2018-03-07'),
('128.68.36.131', '2018-03-07'),
('128.68.102.134', '2018-03-07'),
('95.24.15.137', '2018-03-07'),
('174.117.22.174', '2018-03-08'),
('5.166.239.148', '2018-03-08'),
('216.185.36.81', '2018-03-08'),
('157.55.39.176', '2018-03-08'),
('5.165.182.119', '2018-03-08'),
('77.37.221.94', '2018-03-08'),
('174.117.22.174', '2018-03-09'),
('131.253.27.131', '2018-03-09'),
('95.24.94.142', '2018-03-09'),
('37.146.176.192', '2018-03-10'),
('174.117.22.174', '2018-03-10'),
('109.173.58.101', '2018-03-10'),
('93.80.129.106', '2018-03-11'),
('174.117.22.174', '2018-03-11'),
('158.69.228.184', '2018-03-11'),
('77.37.180.47', '2018-03-11'),
('37.110.147.54', '2018-03-11'),
('128.69.230.161', '2018-03-12'),
('167.114.157.79', '2018-03-12'),
('5.3.147.157', '2018-03-12'),
('109.173.54.119', '2018-03-13'),
('77.37.181.98', '2018-03-13'),
('94.180.155.37', '2018-03-14'),
('46.42.169.223', '2018-03-14'),
('174.117.22.174', '2018-03-14'),
('94.180.155.81', '2018-03-14'),
('128.204.33.123', '2018-03-15'),
('174.117.22.174', '2018-03-15'),
('95.27.128.168', '2018-03-15'),
('180.76.15.7', '2018-03-16'),
('174.117.22.174', '2018-03-16'),
('46.42.164.84', '2018-03-16'),
('95.28.162.238', '2018-03-16'),
('176.212.45.41', '2018-03-16'),
('5.228.157.178', '2018-03-16'),
('95.28.166.52', '2018-03-17'),
('174.117.22.174', '2018-03-17'),
('89.178.92.49', '2018-03-17'),
('174.117.22.174', '2018-03-18'),
('40.77.167.176', '2018-03-18'),
('176.193.170.60', '2018-03-18'),
('46.188.32.27', '2018-03-18'),
('69.58.178.59', '2018-03-19'),
('174.117.22.174', '2018-03-19'),
('95.143.19.207', '2018-03-19'),
('5.228.156.66', '2018-03-20'),
('94.180.224.178', '2018-03-20'),
('128.69.150.180', '2018-03-20'),
('128.69.225.126', '2018-03-20'),
('174.117.22.174', '2018-03-20'),
('109.173.33.135', '2018-03-21'),
('176.14.37.74', '2018-03-21'),
('174.117.22.174', '2018-03-21'),
('37.204.156.141', '2018-03-21'),
('174.117.22.174', '2018-03-22'),
('128.68.111.39', '2018-03-22'),
('37.145.124.191', '2018-03-22'),
('174.117.22.174', '2018-03-23'),
('77.37.168.40', '2018-03-23'),
('188.255.1.73', '2018-03-23'),
('37.144.49.19', '2018-03-23'),
('174.117.22.174', '2018-03-24'),
('95.84.128.167', '2018-03-24'),
('109.173.61.189', '2018-03-25'),
('174.117.22.174', '2018-03-25'),
('46.242.57.219', '2018-03-25'),
('174.117.22.174', '2018-03-26'),
('95.220.107.143', '2018-03-26'),
('176.14.37.74', '2018-03-26'),
('37.204.85.188', '2018-03-26'),
('174.117.22.174', '2018-03-27'),
('128.72.84.237', '2018-03-27'),
('77.37.221.45', '2018-03-27'),
('95.28.162.238', '2018-03-27'),
('37.204.156.184', '2018-03-27'),
('37.110.148.122', '2018-03-28'),
('46.42.178.115', '2018-03-28'),
('180.76.15.144', '2018-03-28'),
('174.117.22.174', '2018-03-28'),
('46.188.40.96', '2018-03-28'),
('174.117.22.174', '2018-03-29'),
('95.221.63.250', '2018-03-30'),
('174.117.22.174', '2018-03-30'),
('27.152.72.152', '2018-03-30'),
('94.180.138.152', '2018-03-30'),
('176.193.125.94', '2018-03-31'),
('174.117.22.174', '2018-03-31'),
('178.140.195.87', '2018-03-31'),
('5.164.168.142', '2018-03-31'),
('95.24.207.40', '2018-03-31'),
('95.143.28.234', '2018-03-31'),
('188.255.19.4', '2018-04-01'),
('174.117.22.174', '2018-04-01'),
('95.143.26.167', '2018-04-01'),
('174.117.22.174', '2018-04-02'),
('109.173.61.189', '2018-04-02'),
('128.72.228.99', '2018-04-02'),
('95.27.44.103', '2018-04-02'),
('174.117.22.174', '2018-04-03'),
('128.69.154.222', '2018-04-03'),
('128.74.247.58', '2018-04-03'),
('95.28.38.218', '2018-04-03'),
('5.228.95.140', '2018-04-03'),
('178.140.124.33', '2018-04-04'),
('174.117.22.174', '2018-04-04'),
('157.55.39.38', '2018-04-04'),
('5.167.113.22', '2018-04-04'),
('174.117.22.174', '2018-04-05'),
('95.28.185.34', '2018-04-05'),
('46.188.107.138', '2018-04-05'),
('5.35.58.221', '2018-04-06'),
('174.117.22.174', '2018-04-06'),
('37.204.191.25', '2018-04-06'),
('178.140.155.33', '2018-04-07'),
('174.117.22.174', '2018-04-07'),
('37.144.49.19', '2018-04-07'),
('109.173.54.197', '2018-04-08'),
('174.117.22.174', '2018-04-09'),
('94.180.212.29', '2018-04-09'),
('5.228.23.17', '2018-04-09'),
('128.69.152.114', '2018-04-09'),
('174.117.22.174', '2018-04-10'),
('5.164.112.209', '2018-04-10'),
('174.117.22.174', '2018-04-11'),
('178.140.117.62', '2018-04-11'),
('119.188.64.4', '2018-04-11'),
('5.164.79.199', '2018-04-11'),
('37.112.228.98', '2018-04-11'),
('95.27.15.16', '2018-04-12'),
('77.37.221.45', '2018-04-12'),
('95.24.31.178', '2018-04-13'),
('46.188.59.114', '2018-04-13'),
('207.46.13.108', '2018-04-13'),
('195.91.224.113', '2018-04-14'),
('174.117.22.174', '2018-04-14'),
('95.24.17.242', '2018-04-14'),
('37.204.157.100', '2018-04-15'),
('104.192.74.19', '2018-04-15'),
('37.110.145.185', '2018-04-15'),
('46.188.52.117', '2018-04-15'),
('174.117.22.174', '2018-04-15'),
('89.179.105.122', '2018-04-16'),
('23.247.82.227', '2018-04-16'),
('158.69.127.133', '2018-04-16'),
('5.3.156.143', '2018-04-16'),
('174.117.22.174', '2018-04-16'),
('37.204.133.231', '2018-04-16'),
('95.27.85.105', '2018-04-17'),
('174.117.22.174', '2018-04-17'),
('37.204.156.184', '2018-04-18'),
('174.117.22.174', '2018-04-18'),
('188.32.6.27', '2018-04-18'),
('46.242.57.219', '2018-04-18'),
('37.110.17.20', '2018-04-19'),
('174.117.22.174', '2018-04-19'),
('128.72.225.101', '2018-04-19'),
('95.84.128.167', '2018-04-20'),
('174.117.22.174', '2018-04-20'),
('66.249.64.23', '2018-04-20'),
('176.193.126.50', '2018-04-20'),
('66.249.64.89', '2018-04-20'),
('94.180.129.95', '2018-04-21'),
('188.255.1.220', '2018-04-21'),
('66.249.66.195', '2018-04-21'),
('40.77.167.25', '2018-04-21'),
('95.24.5.218', '2018-04-22'),
('128.69.236.109', '2018-04-22'),
('174.117.22.174', '2018-04-22'),
('66.249.66.95', '2018-04-22'),
('46.0.22.58', '2018-04-22'),
('174.117.22.174', '2018-04-23'),
('46.242.9.101', '2018-04-23'),
('69.58.178.56', '2018-04-23'),
('5.166.237.38', '2018-04-24'),
('37.204.48.174', '2018-04-25'),
('174.117.22.174', '2018-04-25'),
('95.24.34.33', '2018-04-26'),
('207.46.13.79', '2018-04-26'),
('178.140.15.136', '2018-04-26'),
('174.117.22.174', '2018-04-26'),
('66.249.64.138', '2018-04-26'),
('128.72.208.183', '2018-04-26'),
('104.35.47.162', '2018-04-26'),
('64.246.165.160', '2018-04-27'),
('5.228.60.201', '2018-04-27'),
('174.117.22.174', '2018-04-27'),
('95.28.81.29', '2018-04-28'),
('174.117.22.174', '2018-04-28'),
('89.178.238.106', '2018-04-28'),
('157.55.39.236', '2018-04-28'),
('174.117.22.174', '2018-04-29'),
('178.140.52.87', '2018-04-29'),
('66.249.66.155', '2018-04-30'),
('174.117.22.174', '2018-04-30'),
('244.18.34.11', '2018-04-30'),
('66.249.69.202', '2018-04-30'),
('66.249.69.61', '2018-04-30'),
('46.147.98.83', '2018-04-30'),
('66.249.69.204', '2018-04-30'),
('174.117.22.174', '2018-05-01'),
('128.68.129.219', '2018-05-01'),
('66.249.66.85', '2018-05-01'),
('174.117.22.174', '2018-05-02'),
('94.180.217.113', '2018-05-02'),
('37.204.43.26', '2018-05-02'),
('174.117.22.174', '2018-05-03'),
('46.188.88.171', '2018-05-03'),
('95.84.179.237', '2018-05-03'),
('104.131.172.69', '2018-05-03'),
('46.233.241.182', '2018-05-04'),
('174.117.22.174', '2018-05-04'),
('31.135.83.9', '2018-05-05'),
('5.3.233.117', '2018-05-06'),
('213.180.203.2', '2018-05-06'),
('174.117.22.174', '2018-05-06'),
('178.140.124.234', '2018-05-06'),
('174.117.22.174', '2018-05-07'),
('93.87.123.145', '2018-05-07'),
('207.46.13.160', '2018-05-07'),
('66.249.64.138', '2018-05-07'),
('89.178.225.59', '2018-05-07'),
('77.41.90.78', '2018-05-08'),
('95.28.186.238', '2018-05-08'),
('174.117.22.174', '2018-05-08'),
('46.42.139.108', '2018-05-08'),
('174.117.22.174', '2018-05-09'),
('207.46.13.227', '2018-05-09'),
('46.242.125.69', '2018-05-09'),
('95.28.49.3', '2018-05-10'),
('95.84.139.218', '2018-05-11'),
('95.28.38.218', '2018-05-11'),
('5.165.177.193', '2018-05-11'),
('94.180.136.148', '2018-05-12'),
('37.110.147.222', '2018-05-12'),
('95.220.204.199', '2018-05-13'),
('174.117.22.174', '2018-05-13'),
('5.167.191.64', '2018-05-13'),
('66.249.64.15', '2018-05-13'),
('37.110.107.141', '2018-05-14'),
('174.117.22.174', '2018-05-14'),
('46.242.55.250', '2018-05-14'),
('109.173.58.115', '2018-05-14'),
('174.117.22.174', '2018-05-15'),
('79.111.63.152', '2018-05-15'),
('64.246.161.42', '2018-05-15'),
('95.24.92.187', '2018-05-15'),
('109.173.25.162', '2018-05-16'),
('174.117.22.174', '2018-05-16'),
('89.178.239.5', '2018-05-16'),
('95.28.33.56', '2018-05-16'),
('174.117.22.174', '2018-05-17'),
('94.180.146.214', '2018-05-17'),
('93.80.145.248', '2018-05-17'),
('66.249.64.138', '2018-05-17'),
('157.55.39.188', '2018-05-17'),
('40.77.190.179', '2018-05-18'),
('128.69.202.83', '2018-05-18'),
('174.117.22.174', '2018-05-18'),
('37.144.57.164', '2018-05-18'),
('188.32.245.82', '2018-05-18'),
('174.117.22.174', '2018-05-19'),
('94.180.144.94', '2018-05-19'),
('188.32.45.73', '2018-05-19'),
('46.42.130.127', '2018-05-20'),
('174.117.22.174', '2018-05-20'),
('94.180.131.162', '2018-05-20'),
('95.28.168.99', '2018-05-20'),
('192.99.47.111', '2018-05-20'),
('5.166.210.51', '2018-05-21'),
('174.117.22.174', '2018-05-21'),
('37.204.156.68', '2018-05-21'),
('66.249.64.16', '2018-05-21'),
('88.81.50.219', '2018-05-21'),
('37.145.64.253', '2018-05-22'),
('174.117.22.174', '2018-05-22'),
('95.220.121.212', '2018-05-22'),
('158.69.127.133', '2018-05-22'),
('46.42.129.49', '2018-05-23'),
('69.58.178.58', '2018-05-23'),
('174.117.22.174', '2018-05-23'),
('66.249.66.155', '2018-05-23'),
('66.249.66.202', '2018-05-23'),
('37.144.69.35', '2018-05-23'),
('5.228.148.223', '2018-05-24'),
('128.72.40.13', '2018-05-24'),
('174.117.22.174', '2018-05-24'),
('128.72.228.99', '2018-05-26'),
('174.117.22.174', '2018-05-26'),
('176.193.145.23', '2018-05-26'),
('128.72.209.129', '2018-05-26'),
('95.220.95.241', '2018-05-26'),
('34.204.88.127', '2018-05-26'),
('46.188.32.25', '2018-05-27'),
('40.77.167.59', '2018-05-27'),
('174.117.22.174', '2018-05-27'),
('79.165.171.246', '2018-05-27'),
('128.75.75.143', '2018-05-27'),
('66.249.66.155', '2018-05-27'),
('94.180.240.250', '2018-05-28'),
('174.117.22.174', '2018-05-28'),
('188.255.16.243', '2018-05-28'),
('95.221.131.67', '2018-05-28'),
('46.251.70.75', '2018-05-29'),
('174.117.22.174', '2018-05-29'),
('40.77.167.184', '2018-05-29'),
('95.28.230.92', '2018-05-29'),
('37.146.115.51', '2018-05-29'),
('128.74.244.173', '2018-05-29'),
('46.42.175.216', '2018-05-29'),
('176.15.20.236', '2018-05-30'),
('66.249.66.202', '2018-05-30'),
('188.244.34.215', '2018-05-30'),
('95.24.90.35', '2018-05-30'),
('128.69.196.121', '2018-05-31'),
('174.117.22.174', '2018-05-31'),
('128.69.234.225', '2018-05-31'),
('5.228.33.61', '2018-05-31'),
('176.193.249.190', '2018-06-01'),
('159.65.36.112', '2018-06-01'),
('77.41.88.46', '2018-06-01'),
('89.178.17.50', '2018-06-01'),
('188.255.59.214', '2018-06-01'),
('83.102.199.70', '2018-06-02'),
('64.246.165.50', '2018-06-02'),
('95.84.224.54', '2018-06-02'),
('178.140.108.170', '2018-06-02'),
('5.167.121.192', '2018-06-02'),
('2.92.115.102', '2018-06-03'),
('95.28.190.43', '2018-06-03'),
('128.72.68.75', '2018-06-03'),
('174.117.22.174', '2018-06-03'),
('46.42.132.58', '2018-06-04'),
('128.72.81.25', '2018-06-04'),
('174.117.22.174', '2018-06-04'),
('109.173.26.15', '2018-06-04'),
('188.255.28.126', '2018-06-05'),
('46.42.133.193', '2018-06-05'),
('40.77.167.65', '2018-06-05'),
('37.144.51.189', '2018-06-06'),
('176.193.224.140', '2018-06-06'),
('174.117.22.174', '2018-06-06'),
('128.72.151.219', '2018-06-06'),
('87.228.18.98', '2018-06-07'),
('174.117.22.174', '2018-06-07'),
('40.77.167.196', '2018-06-07'),
('176.14.227.254', '2018-06-07'),
('5.3.155.72', '2018-06-07'),
('95.24.2.217', '2018-06-07'),
('188.32.132.250', '2018-06-08'),
('178.140.119.238', '2018-06-08'),
('207.46.13.112', '2018-06-08'),
('174.117.22.174', '2018-06-08'),
('174.117.22.174', '2018-06-09'),
('37.204.71.200', '2018-06-09'),
('128.75.39.210', '2018-06-09'),
('5.3.235.27', '2018-06-09'),
('37.204.189.158', '2018-06-10'),
('188.32.182.83', '2018-06-10'),
('109.173.61.72', '2018-06-11'),
('94.180.222.243', '2018-06-11'),
('176.14.9.250', '2018-06-11'),
('5.228.21.26', '2018-06-12'),
('128.75.12.127', '2018-06-12'),
('95.27.169.111', '2018-06-12'),
('94.180.220.133', '2018-06-12'),
('128.69.223.88', '2018-06-12'),
('37.110.129.81', '2018-06-12'),
('66.249.64.140', '2018-06-12'),
('95.28.165.113', '2018-06-12'),
('217.114.227.184', '2018-06-13'),
('95.24.18.154', '2018-06-13'),
('95.221.150.108', '2018-06-13'),
('66.249.66.156', '2018-06-13'),
('37.204.38.162', '2018-06-13'),
('157.55.39.120', '2018-06-14'),
('174.117.22.174', '2018-06-14'),
('176.193.106.198', '2018-06-14'),
('66.249.66.155', '2018-06-14'),
('89.178.238.106', '2018-06-14'),
('95.84.198.118', '2018-06-14'),
('46.188.90.253', '2018-06-15'),
('37.204.211.29', '2018-06-15'),
('95.24.133.206', '2018-06-15'),
('128.69.239.105', '2018-06-15'),
('90.154.47.14', '2018-06-16'),
('157.55.39.161', '2018-06-16'),
('128.69.161.51', '2018-06-16'),
('128.68.220.174', '2018-06-17'),
('174.117.22.174', '2018-06-17'),
('178.140.120.77', '2018-06-17'),
('5.228.148.223', '2018-06-17'),
('66.249.64.138', '2018-06-17'),
('95.28.177.221', '2018-06-17'),
('176.193.147.7', '2018-06-18'),
('66.249.64.138', '2018-06-18'),
('66.249.64.142', '2018-06-18'),
('174.117.22.174', '2018-06-18'),
('176.193.97.170', '2018-06-18'),
('95.220.103.232', '2018-06-18'),
('37.147.103.119', '2018-06-19'),
('37.204.54.84', '2018-06-19'),
('5.228.54.78', '2018-06-19'),
('174.117.22.174', '2018-06-20'),
('64.246.165.190', '2018-06-20'),
('167.114.117.176', '2018-06-20'),
('128.75.88.133', '2018-06-20'),
('37.204.201.86', '2018-06-21'),
('95.28.230.92', '2018-06-21'),
('174.117.22.174', '2018-06-21'),
('37.145.10.63', '2018-06-21'),
('46.188.29.95', '2018-06-21'),
('128.72.84.237', '2018-06-22'),
('5.228.102.211', '2018-06-22'),
('79.111.108.140', '2018-06-22'),
('174.117.22.174', '2018-06-22'),
('95.143.20.160', '2018-06-22'),
('37.110.32.39', '2018-06-22'),
('2.92.35.126', '2018-06-22'),
('178.140.84.73', '2018-06-22'),
('174.117.22.174', '2018-06-23'),
('93.80.63.6', '2018-06-23'),
('66.249.64.15', '2018-06-23'),
('37.147.243.95', '2018-06-24'),
('174.117.22.174', '2018-06-24'),
('37.204.71.200', '2018-06-24'),
('46.242.71.243', '2018-06-24'),
('95.220.205.79', '2018-06-24'),
('174.117.22.174', '2018-06-25'),
('5.228.196.81', '2018-06-25'),
('46.42.145.64', '2018-06-25'),
('185.150.154.201', '2018-06-25'),
('128.72.111.149', '2018-06-26'),
('109.63.218.221', '2018-06-26'),
('174.117.22.174', '2018-06-26'),
('46.188.32.27', '2018-06-26'),
('176.14.243.50', '2018-06-27'),
('174.117.22.174', '2018-06-27'),
('40.77.167.159', '2018-06-27'),
('37.204.53.200', '2018-06-27'),
('178.140.155.103', '2018-06-28'),
('174.117.22.174', '2018-06-28'),
('5.167.191.81', '2018-06-29'),
('128.72.67.227', '2018-06-29'),
('95.220.76.182', '2018-06-29'),
('40.77.167.159', '2018-06-29'),
('40.77.189.26', '2018-06-29'),
('174.117.22.174', '2018-06-29'),
('174.117.22.174', '2018-06-30'),
('178.140.119.230', '2018-06-30'),
('89.178.172.91', '2018-06-30'),
('66.249.66.85', '2018-06-30'),
('109.173.47.139', '2018-07-01'),
('188.32.172.181', '2018-07-01'),
('46.188.107.59', '2018-07-01'),
('174.117.22.174', '2018-07-01'),
('40.77.167.54', '2018-07-01'),
('95.221.49.174', '2018-07-02'),
('174.117.22.174', '2018-07-02'),
('128.69.236.81', '2018-07-02'),
('66.249.69.149', '2018-07-03'),
('174.117.22.174', '2018-07-03'),
('85.91.192.97', '2018-07-03'),
('159.65.36.22', '2018-07-03'),
('95.220.71.96', '2018-07-04'),
('40.77.167.54', '2018-07-04'),
('128.68.56.234', '2018-07-04'),
('109.173.26.15', '2018-07-04'),
('178.140.119.238', '2018-07-04'),
('95.28.230.92', '2018-07-05'),
('5.228.148.223', '2018-07-05'),
('66.249.69.93', '2018-07-06'),
('77.37.161.20', '2018-07-06'),
('128.72.228.27', '2018-07-06'),
('128.68.48.243', '2018-07-07'),
('109.173.26.15', '2018-07-07'),
('5.3.236.223', '2018-07-08'),
('94.180.144.225', '2018-07-08'),
('216.145.14.142', '2018-07-08'),
('95.28.5.240', '2018-07-08'),
('157.55.39.64', '2018-07-08'),
('128.74.246.227', '2018-07-09'),
('188.32.76.34', '2018-07-09'),
('178.140.85.196', '2018-07-10'),
('157.55.39.64', '2018-07-10'),
('180.183.204.146', '2018-07-11'),
('178.140.196.41', '2018-07-11'),
('5.166.150.71', '2018-07-11'),
('37.144.78.30', '2018-07-12'),
('37.110.38.228', '2018-07-12'),
('89.178.238.76', '2018-07-12'),
('94.180.147.199', '2018-07-12'),
('46.188.106.127', '2018-07-13'),
('37.204.254.81', '2018-07-13'),
('180.183.202.165', '2018-07-13'),
('109.173.25.253', '2018-07-14'),
('180.183.202.165', '2018-07-14'),
('128.69.231.251', '2018-07-14'),
('178.140.196.41', '2018-07-15'),
('46.188.51.229', '2018-07-15'),
('180.183.202.165', '2018-07-15'),
('95.24.23.68', '2018-07-15'),
('180.183.157.118', '2018-07-16'),
('94.180.162.35', '2018-07-16'),
('46.42.172.123', '2018-07-16'),
('178.140.0.41', '2018-07-16'),
('89.178.239.5', '2018-07-17'),
('87.240.61.85', '2018-07-17'),
('87.240.57.173', '2018-07-18'),
('37.110.129.90', '2018-07-18'),
('95.24.94.21', '2018-07-18'),
('180.183.157.118', '2018-07-18'),
('5.228.196.81', '2018-07-18'),
('27.115.124.66', '2018-07-19'),
('180.183.157.118', '2018-07-19'),
('40.77.167.61', '2018-07-19'),
('176.14.243.50', '2018-07-19'),
('180.183.203.145', '2018-07-19'),
('89.178.238.76', '2018-07-20'),
('188.32.114.69', '2018-07-20'),
('158.69.225.37', '2018-07-20'),
('180.183.203.145', '2018-07-20'),
('77.37.231.149', '2018-07-20'),
('40.77.167.61', '2018-07-21'),
('128.68.20.143', '2018-07-21'),
('116.206.33.63', '2018-07-21'),
('66.249.66.85', '2018-07-22'),
('95.27.11.12', '2018-07-22'),
('77.37.192.101', '2018-07-22'),
('178.140.111.9', '2018-07-22'),
('180.183.203.145', '2018-07-23'),
('95.220.214.197', '2018-07-23'),
('180.183.152.86', '2018-07-23'),
('128.69.213.75', '2018-07-24'),
('128.72.121.20', '2018-07-24'),
('180.183.203.145', '2018-07-24'),
('37.144.46.130', '2018-07-24'),
('180.183.203.145', '2018-07-25'),
('40.77.188.34', '2018-07-25'),
('180.183.203.145', '2018-07-26'),
('66.249.66.155', '2018-07-26'),
('95.220.81.231', '2018-07-26'),
('216.145.5.42', '2018-07-26'),
('180.183.203.145', '2018-07-27'),
('66.249.66.155', '2018-07-27'),
('37.146.180.200', '2018-07-27'),
('37.204.43.250', '2018-07-28'),
('128.68.30.142', '2018-07-28'),
('180.183.203.145', '2018-07-28'),
('37.204.75.254', '2018-07-28'),
('180.183.202.134', '2018-07-29'),
('95.28.186.238', '2018-07-29'),
('128.74.163.149', '2018-07-30'),
('158.69.148.216', '2018-07-30'),
('46.242.111.254', '2018-07-30'),
('40.77.167.66', '2018-07-30'),
('180.183.202.134', '2018-07-30'),
('95.28.182.4', '2018-07-30'),
('180.183.202.134', '2018-07-31'),
('37.110.145.222', '2018-07-31'),
('46.42.134.241', '2018-08-01'),
('40.77.167.119', '2018-08-01'),
('192.99.150.97', '2018-08-01'),
('66.249.69.125', '2018-08-01'),
('95.28.182.4', '2018-08-01'),
('5.228.32.182', '2018-08-02'),
('180.183.202.134', '2018-08-02'),
('40.77.167.119', '2018-08-02'),
('5.164.80.129', '2018-08-02'),
('40.77.167.80', '2018-08-03'),
('89.179.107.253', '2018-08-03'),
('66.249.66.202', '2018-08-03'),
('37.204.189.179', '2018-08-04'),
('5.165.248.248', '2018-08-04'),
('40.77.167.80', '2018-08-04'),
('128.72.37.125', '2018-08-04'),
('36.37.134.205', '2018-08-05'),
('37.145.34.255', '2018-08-06'),
('176.193.94.72', '2018-08-06'),
('46.42.166.187', '2018-08-06'),
('95.24.237.37', '2018-08-07'),
('95.84.155.132', '2018-08-07'),
('180.183.202.134', '2018-08-07'),
('180.183.202.134', '2018-08-08'),
('184.82.29.131', '2018-08-08'),
('207.46.13.43', '2018-08-08'),
('128.75.39.252', '2018-08-08'),
('184.82.30.158', '2018-08-09'),
('46.188.81.162', '2018-08-09'),
('120.84.11.149', '2018-08-09'),
('167.99.120.12', '2018-08-09'),
('128.75.20.66', '2018-08-10'),
('174.117.22.174', '2018-08-11'),
('207.46.13.177', '2018-08-11'),
('66.249.64.93', '2018-08-12'),
('207.46.13.177', '2018-08-12'),
('89.179.107.50', '2018-08-12'),
('174.117.22.174', '2018-08-12'),
('174.117.22.174', '2018-08-13'),
('64.246.165.210', '2018-08-13'),
('173.252.87.3', '2018-08-13'),
('207.46.13.177', '2018-08-14'),
('174.117.22.174', '2018-08-14'),
('77.37.224.73', '2018-08-14'),
('174.117.22.174', '2018-08-15'),
('66.249.64.138', '2018-08-15'),
('174.117.22.174', '2018-08-16'),
('95.220.209.74', '2018-08-16'),
('37.110.18.165', '2018-08-16'),
('37.204.75.202', '2018-08-16'),
('174.117.22.174', '2018-08-17'),
('157.55.39.17', '2018-08-17'),
('37.147.247.118', '2018-08-17'),
('95.220.199.133', '2018-08-18'),
('85.91.192.251', '2018-08-19'),
('174.117.22.174', '2018-08-19'),
('95.28.167.1', '2018-08-19'),
('174.117.22.174', '2018-08-20'),
('40.77.167.53', '2018-08-20'),
('174.117.22.174', '2018-08-21'),
('66.249.66.85', '2018-08-21'),
('94.180.236.103', '2018-08-21'),
('37.110.81.9', '2018-08-21'),
('128.69.228.58', '2018-08-22'),
('174.117.22.174', '2018-08-22'),
('174.117.22.174', '2018-08-23'),
('37.110.55.206', '2018-08-23'),
('213.180.203.2', '2018-08-23'),
('188.244.36.217', '2018-08-23'),
('95.220.84.169', '2018-08-24'),
('66.249.64.221', '2018-08-24'),
('174.117.22.174', '2018-08-24'),
('205.189.187.4', '2018-08-25'),
('46.242.68.138', '2018-08-25'),
('207.46.13.154', '2018-08-25'),
('40.77.252.196', '2018-08-25'),
('174.117.22.174', '2018-08-25'),
('89.178.17.50', '2018-08-25'),
('174.117.22.174', '2018-08-26'),
('188.32.248.28', '2018-08-26'),
('66.249.64.140', '2018-08-27'),
('207.46.13.241', '2018-08-27'),
('173.252.127.8', '2018-08-27'),
('66.249.64.223', '2018-08-27'),
('128.69.199.230', '2018-08-27'),
('174.117.22.174', '2018-08-28'),
('205.189.187.4', '2018-08-28'),
('176.193.157.235', '2018-08-28'),
('174.117.22.174', '2018-08-29'),
('128.72.84.237', '2018-08-29'),
('95.143.25.29', '2018-08-29'),
('207.46.13.248', '2018-08-29'),
('205.189.187.4', '2018-08-29'),
('174.117.22.174', '2018-08-30'),
('5.165.180.246', '2018-08-30'),
('205.189.187.4', '2018-08-30'),
('66.249.64.138', '2018-08-31'),
('174.117.22.174', '2018-08-31'),
('42.236.10.75', '2018-08-31'),
('180.163.220.100', '2018-08-31'),
('207.46.13.188', '2018-08-31'),
('216.145.5.42', '2018-08-31'),
('37.144.46.130', '2018-08-31'),
('128.75.113.161', '2018-09-01'),
('94.180.155.59', '2018-09-01'),
('174.117.22.174', '2018-09-01'),
('174.117.22.174', '2018-09-02'),
('128.72.84.237', '2018-09-02'),
('37.204.205.223', '2018-09-03'),
('174.117.22.174', '2018-09-03'),
('95.28.220.161', '2018-09-03'),
('66.249.64.221', '2018-09-04'),
('174.117.22.174', '2018-09-04'),
('87.228.16.209', '2018-09-04'),
('94.180.255.7', '2018-09-05'),
('173.252.95.22', '2018-09-05'),
('174.117.22.174', '2018-09-06'),
('94.181.104.220', '2018-09-06'),
('128.72.81.25', '2018-09-07'),
('18.209.63.194', '2018-09-07'),
('174.117.22.174', '2018-09-07'),
('167.114.65.240', '2018-09-07'),
('66.249.64.208', '2018-09-07'),
('207.46.13.120', '2018-09-07'),
('66.249.64.157', '2018-09-07'),
('207.46.13.120', '2018-09-08'),
('77.37.211.151', '2018-09-08'),
('174.117.22.174', '2018-09-09'),
('40.77.167.198', '2018-09-09'),
('5.3.144.194', '2018-09-09'),
('174.117.22.174', '2018-09-10'),
('66.249.64.157', '2018-09-11'),
('174.117.22.174', '2018-09-11'),
('66.249.64.202', '2018-09-11'),
('174.117.22.174', '2018-09-12'),
('128.72.81.25', '2018-09-12'),
('37.204.201.140', '2018-09-13'),
('178.140.88.218', '2018-09-13'),
('5.167.127.153', '2018-09-13'),
('174.117.22.174', '2018-09-14'),
('157.55.39.38', '2018-09-14'),
('174.117.22.174', '2018-09-15'),
('95.24.133.206', '2018-09-15'),
('128.69.223.88', '2018-09-15'),
('174.117.22.174', '2018-09-16'),
('176.14.10.12', '2018-09-16'),
('109.63.141.83', '2018-09-16'),
('109.173.58.87', '2018-09-18'),
('174.117.22.174', '2018-09-18'),
('64.246.187.42', '2018-09-18'),
('174.117.22.174', '2018-09-19'),
('174.117.22.174', '2018-09-20'),
('66.249.64.202', '2018-09-21'),
('174.117.22.174', '2018-09-21'),
('204.191.190.24', '2018-09-22'),
('174.117.22.174', '2018-09-22'),
('188.255.17.81', '2018-09-22'),
('174.117.22.174', '2018-09-23'),
('174.117.22.174', '2018-09-24'),
('109.173.57.189', '2018-09-24'),
('174.117.22.174', '2018-09-25'),
('174.117.22.174', '2018-09-26'),
('66.249.65.174', '2018-09-26'),
('188.32.106.38', '2018-09-26'),
('173.252.87.5', '2018-09-27'),
('66.249.64.159', '2018-09-27'),
('174.117.22.174', '2018-09-27'),
('174.117.22.174', '2018-09-28'),
('95.24.0.251', '2018-09-28'),
('216.38.152.26', '2018-09-28'),
('70.49.49.13', '2018-09-30'),
('174.117.22.174', '2018-10-01'),
('128.69.219.33', '2018-10-02'),
('142.93.68.81', '2018-10-02'),
('159.89.41.25', '2018-10-02'),
('207.46.13.110', '2018-10-02'),
('174.117.22.174', '2018-10-03'),
('35.187.132.180', '2018-10-03'),
('146.148.69.73', '2018-10-03'),
('66.102.9.141', '2018-10-03'),
('66.102.9.143', '2018-10-03'),
('174.117.22.174', '2018-10-04'),
('79.111.96.122', '2018-10-04'),
('128.69.221.211', '2018-10-04'),
('174.117.22.174', '2018-10-05'),
('174.117.22.174', '2018-10-06'),
('64.246.165.180', '2018-10-07'),
('158.69.127.133', '2018-10-07'),
('66.249.64.221', '2018-10-08'),
('66.249.64.223', '2018-10-08'),
('174.117.22.174', '2018-10-08'),
('46.188.32.25', '2018-10-08'),
('95.29.101.31', '2018-10-09'),
('174.117.22.174', '2018-10-09'),
('66.249.64.31', '2018-10-09'),
('176.99.209.86', '2018-10-10'),
('89.178.231.84', '2018-10-10'),
('174.117.22.174', '2018-10-11'),
('95.45.252.1', '2018-10-11'),
('174.117.22.174', '2018-10-12'),
('174.117.22.174', '2018-10-13'),
('40.77.252.129', '2018-10-13'),
('174.117.22.174', '2018-10-14'),
('40.77.188.226', '2018-10-14'),
('94.180.139.61', '2018-10-14'),
('37.145.68.106', '2018-10-14'),
('188.255.17.81', '2018-10-15'),
('207.46.13.119', '2018-10-15'),
('128.69.235.240', '2018-10-16'),
('174.117.22.174', '2018-10-16'),
('69.171.251.14', '2018-10-16'),
('174.117.22.174', '2018-10-17'),
('174.117.22.174', '2018-10-18'),
('37.204.32.18', '2018-10-18'),
('95.28.177.221', '2018-10-18'),
('109.173.57.189', '2018-10-19'),
('188.232.120.65', '2018-10-19'),
('158.69.225.35', '2018-10-20'),
('174.117.22.174', '2018-10-20'),
('174.117.22.174', '2018-10-21'),
('174.117.22.174', '2018-10-22'),
('205.189.187.4', '2018-10-22'),
('174.117.22.174', '2018-10-23'),
('66.249.64.138', '2018-10-23'),
('109.63.230.34', '2018-10-24'),
('94.180.158.66', '2018-10-24'),
('174.117.22.174', '2018-10-25'),
('205.189.187.4', '2018-10-25'),
('188.32.128.64', '2018-10-25'),
('174.117.22.174', '2018-10-26'),
('176.193.130.103', '2018-10-26'),
('66.249.64.140', '2018-10-26'),
('104.192.74.21', '2018-10-27'),
('93.80.32.83', '2018-10-27'),
('37.145.10.63', '2018-10-27'),
('174.117.22.174', '2018-10-28'),
('64.246.165.50', '2018-10-28'),
('46.42.128.74', '2018-10-28'),
('66.249.64.221', '2018-10-28'),
('128.68.19.178', '2018-10-30'),
('157.55.39.223', '2018-10-31'),
('128.69.166.41', '2018-11-01'),
('159.89.180.148', '2018-11-01'),
('159.203.164.160', '2018-11-02'),
('207.46.13.183', '2018-11-02'),
('174.117.22.174', '2018-11-02'),
('207.46.13.183', '2018-11-03'),
('95.28.182.4', '2018-11-04'),
('174.117.22.174', '2018-11-04'),
('157.55.39.217', '2018-11-04'),
('174.117.22.174', '2018-11-05'),
('77.37.153.114', '2018-11-05'),
('174.117.22.174', '2018-11-06'),
('5.166.235.25', '2018-11-06'),
('37.145.230.150', '2018-11-06'),
('128.75.75.166', '2018-11-07'),
('174.117.22.174', '2018-11-07'),
('188.32.37.146', '2018-11-07'),
('174.117.22.174', '2018-11-08'),
('66.249.64.221', '2018-11-08'),
('46.0.39.50', '2018-11-08'),
('66.249.64.138', '2018-11-09'),
('95.29.111.20', '2018-11-09'),
('95.24.25.144', '2018-11-09'),
('37.204.75.254', '2018-11-10'),
('95.24.133.206', '2018-11-10'),
('66.249.64.221', '2018-11-11'),
('95.24.136.115', '2018-11-11'),
('174.117.22.174', '2018-11-12'),
('93.80.129.106', '2018-11-13'),
('188.32.244.32', '2018-11-13'),
('37.144.40.52', '2018-11-13'),
('174.117.22.174', '2018-11-14'),
('40.77.167.73', '2018-11-14'),
('174.117.22.174', '2018-11-15'),
('128.69.237.185', '2018-11-15'),
('94.180.147.54', '2018-11-15'),
('89.178.238.76', '2018-11-15'),
('180.163.220.66', '2018-11-16'),
('180.163.220.124', '2018-11-16'),
('174.117.22.174', '2018-11-16'),
('216.145.17.190', '2018-11-16'),
('174.117.22.174', '2018-11-17'),
('46.147.144.243', '2018-11-17'),
('209.95.51.167', '2018-11-18'),
('40.77.194.16', '2018-11-18'),
('174.117.22.174', '2018-11-19'),
('79.111.140.25', '2018-11-19'),
('46.42.171.238', '2018-11-19'),
('87.240.53.31', '2018-11-20'),
('173.252.95.20', '2018-11-21'),
('87.240.61.85', '2018-11-21'),
('174.117.22.174', '2018-11-21'),
('174.117.22.174', '2018-11-22'),
('46.242.70.219', '2018-11-22'),
('174.117.22.174', '2018-11-23'),
('128.69.221.211', '2018-11-23'),
('66.249.64.138', '2018-11-24'),
('128.74.163.149', '2018-11-25'),
('5.3.146.107', '2018-11-25'),
('157.55.39.100', '2018-11-25'),
('66.249.66.86', '2018-11-25'),
('174.117.22.174', '2018-11-26'),
('157.55.39.100', '2018-11-26'),
('174.117.22.174', '2018-11-27'),
('46.188.33.126', '2018-11-27'),
('128.69.235.240', '2018-11-27'),
('46.42.128.174', '2018-11-27'),
('176.193.121.255', '2018-11-27'),
('89.178.238.106', '2018-11-27'),
('174.117.22.174', '2018-11-28'),
('157.55.39.162', '2018-11-28'),
('188.32.68.130', '2018-11-28'),
('174.117.22.174', '2018-11-29'),
('91.220.166.148', '2018-11-29'),
('143.202.218.135', '2018-11-29'),
('94.180.134.133', '2018-11-29'),
('90.154.40.145', '2018-11-29'),
('5.228.174.117', '2018-11-30'),
('5.165.253.105', '2018-11-30'),
('174.117.22.174', '2018-12-01'),
('188.32.68.130', '2018-12-01'),
('128.69.231.53', '2018-12-01'),
('5.228.43.138', '2018-12-01'),
('95.84.145.219', '2018-12-02'),
('79.111.110.27', '2018-12-02'),
('174.117.22.174', '2018-12-02'),
('174.117.22.174', '2018-12-03'),
('93.80.132.80', '2018-12-03'),
('5.3.235.186', '2018-12-03'),
('174.117.22.174', '2018-12-04'),
('174.117.22.174', '2018-12-05'),
('159.65.189.154', '2018-12-05'),
('176.14.9.250', '2018-12-06'),
('174.117.22.174', '2018-12-06'),
('174.117.22.174', '2018-12-07'),
('94.180.180.180', '2018-12-07'),
('174.117.22.174', '2018-12-08'),
('37.146.242.212', '2018-12-08'),
('46.188.32.25', '2018-12-08'),
('87.228.16.209', '2018-12-09'),
('158.69.225.37', '2018-12-09'),
('66.249.66.85', '2018-12-09'),
('46.242.32.245', '2018-12-09'),
('173.252.95.22', '2018-12-10'),
('174.117.22.174', '2018-12-10'),
('46.188.32.25', '2018-12-10'),
('188.32.166.153', '2018-12-11'),
('128.69.237.185', '2018-12-11'),
('188.32.151.16', '2018-12-11'),
('174.117.22.174', '2018-12-12'),
('188.32.120.156', '2018-12-12'),
('66.249.69.66', '2018-12-12'),
('207.46.13.8', '2018-12-12'),
('95.28.229.72', '2018-12-13'),
('174.117.22.174', '2018-12-13'),
('128.69.237.185', '2018-12-14'),
('174.117.22.174', '2018-12-14'),
('109.173.40.29', '2018-12-14'),
('213.180.203.2', '2018-12-14'),
('40.77.167.58', '2018-12-14'),
('128.68.211.235', '2018-12-15'),
('174.117.22.174', '2018-12-15'),
('46.254.221.3', '2018-12-15'),
('37.204.201.64', '2018-12-15'),
('174.117.22.174', '2018-12-16'),
('188.255.17.81', '2018-12-16'),
('128.72.43.167', '2018-12-17'),
('174.117.22.174', '2018-12-17'),
('188.32.149.236', '2018-12-18'),
('174.117.22.174', '2018-12-18'),
('37.144.58.84', '2018-12-19'),
('174.117.22.174', '2018-12-19'),
('176.15.193.161', '2018-12-20'),
('46.242.32.245', '2018-12-20'),
('128.69.144.84', '2018-12-21'),
('89.178.239.5', '2018-12-21'),
('5.165.252.214', '2018-12-22'),
('95.221.55.244', '2018-12-23'),
('174.117.22.174', '2018-12-23'),
('174.117.22.174', '2018-12-24'),
('128.68.208.104', '2018-12-24'),
('46.242.74.78', '2018-12-24'),
('87.240.53.31', '2018-12-25'),
('174.117.22.174', '2018-12-25'),
('66.249.66.155', '2018-12-26'),
('95.84.149.109', '2018-12-27'),
('89.179.106.247', '2018-12-27'),
('104.151.24.105', '2018-12-27'),
('66.249.66.85', '2018-12-27'),
('89.179.104.162', '2018-12-28'),
('128.72.43.167', '2018-12-29'),
('174.117.22.174', '2018-12-29'),
('207.46.13.10', '2018-12-30'),
('174.117.22.174', '2018-12-30'),
('66.249.66.86', '2018-12-30'),
('95.220.212.80', '2018-12-30'),
('207.46.13.86', '2019-01-01'),
('174.117.22.174', '2019-01-02'),
('37.145.56.99', '2019-01-02'),
('40.77.192.133', '2019-01-02'),
('5.165.251.149', '2019-01-02'),
('68.183.144.196', '2019-01-03'),
('76.69.150.132', '2019-01-03'),
('95.24.27.136', '2019-01-03'),
('66.249.66.155', '2019-01-04'),
('95.28.229.72', '2019-01-04'),
('76.69.148.147', '2019-01-04'),
('5.165.241.92', '2019-01-05'),
('178.140.166.61', '2019-01-05'),
('157.55.39.68', '2019-01-06'),
('85.30.249.113', '2019-01-06'),
('174.117.22.174', '2019-01-06'),
('188.32.149.236', '2019-01-08'),
('174.117.22.174', '2019-01-08');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `article`
--
ALTER TABLE `article`
  ADD PRIMARY KEY (`articleid`);

--
-- Indexes for table `articlebookmarks`
--
ALTER TABLE `articlebookmarks`
  ADD KEY `nc_uid` (`uid`);

--
-- Indexes for table `articleimages`
--
ALTER TABLE `articleimages`
  ADD PRIMARY KEY (`imageid`);

--
-- Indexes for table `articlelinks`
--
ALTER TABLE `articlelinks`
  ADD PRIMARY KEY (`linkid`);
ALTER TABLE `articlelinks` ADD FULLTEXT KEY `FT_LINKTITLE` (`title`);

--
-- Indexes for table `articleunreviewed`
--
ALTER TABLE `articleunreviewed`
  ADD PRIMARY KEY (`aurid`);

--
-- Indexes for table `comments`
--
ALTER TABLE `comments`
  ADD PRIMARY KEY (`cid`);

--
-- Indexes for table `dictionary`
--
ALTER TABLE `dictionary`
  ADD PRIMARY KEY (`dictionaryid`);

--
-- Indexes for table `location`
--
ALTER TABLE `location`
  ADD PRIMARY KEY (`lid`),
  ADD KEY `lid` (`lid`);

--
-- Indexes for table `message`
--
ALTER TABLE `message`
  ADD PRIMARY KEY (`mid`);

--
-- Indexes for table `messageexchange`
--
ALTER TABLE `messageexchange`
  ADD PRIMARY KEY (`meid`);

--
-- Indexes for table `session`
--
ALTER TABLE `session`
  ADD PRIMARY KEY (`sid`);

--
-- Indexes for table `userinformation`
--
ALTER TABLE `userinformation`
  ADD PRIMARY KEY (`uiid`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`uid`,`email`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `uid_UNIQUE` (`uid`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `article`
--
ALTER TABLE `article`
  MODIFY `articleid` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=25;

--
-- AUTO_INCREMENT for table `articleimages`
--
ALTER TABLE `articleimages`
  MODIFY `imageid` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `articlelinks`
--
ALTER TABLE `articlelinks`
  MODIFY `linkid` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1941;

--
-- AUTO_INCREMENT for table `articleunreviewed`
--
ALTER TABLE `articleunreviewed`
  MODIFY `aurid` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `comments`
--
ALTER TABLE `comments`
  MODIFY `cid` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `dictionary`
--
ALTER TABLE `dictionary`
  MODIFY `dictionaryid` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=91;

--
-- AUTO_INCREMENT for table `location`
--
ALTER TABLE `location`
  MODIFY `lid` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=117;

--
-- AUTO_INCREMENT for table `message`
--
ALTER TABLE `message`
  MODIFY `mid` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `messageexchange`
--
ALTER TABLE `messageexchange`
  MODIFY `meid` bigint(20) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `session`
--
ALTER TABLE `session`
  MODIFY `sid` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1511;

--
-- AUTO_INCREMENT for table `userinformation`
--
ALTER TABLE `userinformation`
  MODIFY `uiid` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=66;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `uid` bigint(20) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=88;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
