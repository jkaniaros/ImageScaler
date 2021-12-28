/* 
Output 
*/

-- Activate terminal output
set serveroutput on size 1000000 ;
-- Get Java-Output on terminal
exec dbms_java.set_output(1000000) ;

set define off


/*
Java Source in Oracle DB
*/


CREATE OR REPLACE AND RESOLVE JAVA SOURCE NAMED"Scaler" AS
import oracle.jdbc.driver.*;
import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.OutputStream;

public class Scaler {
    public static oracle.sql.BLOB rescale(oracle.sql.BLOB mediacontent, int targetWidth, int targetHeight, String mimeType) throws Exception {
        oracle.jdbc.OracleConnection conn = (oracle.jdbc.OracleConnection) new OracleDriver().defaultConnection();

        // MimeType image
        if (!mimeType.startsWith("image")) {
            throw new IllegalArgumentException("MimeType not correct! Only images accepted!");
        }

        mimeType = mimeType.substring(6);
        System.out.println("MimeType: " + mimeType);

        // convert Blob to BufferedImage
        BufferedImage image = ImageIO.read(mediacontent.getBinaryStream());

        // scale BufferedImage as Image
        Image resultingImage;

        // Keep aspect ratio
        if (true) {

            int imgHeight = image.getHeight();
            int imgWidth = image.getWidth();
            System.out.println("Width: " + imgWidth + ", Height: " + imgHeight);

            // Calculate target height and width
            if (targetWidth != 0 && targetHeight != 0) {

                double heights = imgHeight / targetHeight;
                double widths = imgWidth / targetWidth;

                if (widths > heights) {
                    targetHeight = (int) (imgHeight / widths);
                } else {
                    targetWidth = (int) (imgWidth / heights);
                }

            } else if (targetHeight == 0 && targetWidth != 0) {

                double widths = imgWidth / targetWidth;
                targetHeight = (int) (imgHeight / widths);

            } else if (targetHeight != 0 && targetWidth == 0) {

                double heights = imgHeight / targetHeight;
                targetWidth = (int) (imgWidth / heights);

            }
        }

        resultingImage = image.getScaledInstance(targetWidth, targetHeight, Image.SCALE_SMOOTH);

        System.out.println("New Width: " + targetWidth + ", New Height: " + targetHeight);
        
        // save scaled Image as BufferedImage
        BufferedImage outputImage = new BufferedImage(targetWidth, targetHeight, BufferedImage.TYPE_INT_RGB);
        outputImage.getGraphics().drawImage(resultingImage, 0, 0, null);

        // get png output stream of BufferedImage
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        ImageIO.write(outputImage, mimeType, baos);

        oracle.sql.BLOB retBlob = oracle.sql.BLOB.createTemporary(conn, true, oracle.sql.BLOB.DURATION_SESSION);

        OutputStream outStr = retBlob.setBinaryStream(0);

        outStr.write(baos.toByteArray());
        outStr.flush();

        return retBlob;
    }
}


/*
Java Function in Oracle DB
*/


CREATE OR REPLACE FUNCTION SCALER(media_content IN BLOB, width IN pls_integer, height IN pls_integer, mimeType IN varchar2) RETURN BLOB
AS LANGUAGE JAVA NAME 'Scaler.rescale(oracle.sql.BLOB, int, int, java.lang.String) return oracle.sql.BLOB';


/*

*/


DECLARE
  l_newimg BLOB;
  l_img BLOB;
BEGIN
  select medium_content into l_img from ams_media where medium_id = '';
  
  SYS.DBMS_OUTPUT.PUT_LINE('l_img: ' || SYS.DBMS_LOB.GETLENGTH(l_img));
  
  l_newimg := SCALER(l_img, 300, 300, 'image/png');
  
  SYS.DBMS_OUTPUT.PUT_LINE('l_img: ' || SYS.DBMS_LOB.GETLENGTH(l_img));
  SYS.DBMS_OUTPUT.PUT_LINE('l_newimg: ' || SYS.DBMS_LOB.GETLENGTH(l_newimg));
  
  insert into ams_media (medium_content) values (l_newimg);
  
END;


/*
Select all images
*/


select * from ams_media;


/*
Delete test images
*/


delete from ams_media where application_id is null;