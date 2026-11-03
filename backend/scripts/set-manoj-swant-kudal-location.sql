-- Sets Dr. Manoj Swant's clinic address and map location to Kudal, Sindhudurg.
-- Works whether his login is still 9876000001 or already 9000000001.
-- Coordinates are Kudal town centre; fine-tune later with the map pin in the app.

SET XACT_ABORT ON;

DECLARE @address   NVARCHAR(50)  = 'Kudal, Sindhudurg';
DECLARE @latitude  DECIMAL(10,7) = 16.0121000;
DECLARE @longitude DECIMAL(10,7) = 73.6889000;

-- Preview
SELECT d.doctor_id, d.name, d.mobile, c.clinic_id, c.clinic_address, c.latitude, c.longitude
FROM doctor_login d
JOIN clinics c ON c.doctor_id = d.doctor_id
WHERE d.mobile IN ('9876000001', '9000000001');

BEGIN TRAN;

UPDATE c
SET c.clinic_address = @address,
    c.latitude       = @latitude,
    c.longitude      = @longitude
FROM clinics c
JOIN doctor_login d ON d.doctor_id = c.doctor_id
WHERE d.mobile IN ('9876000001', '9000000001');

COMMIT TRAN;

SELECT d.doctor_id, d.name, d.mobile, c.clinic_id, c.clinic_address, c.latitude, c.longitude
FROM doctor_login d
JOIN clinics c ON c.doctor_id = d.doctor_id
WHERE d.mobile IN ('9876000001', '9000000001');
