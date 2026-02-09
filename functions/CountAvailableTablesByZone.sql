use dineflow;
DELIMITER $

CREATE FUNCTION CountAvailableTablesByZone(p_location_zone VARCHAR(20))
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    
    SELECT COUNT(*) INTO v_count
    FROM restaurant_table
    WHERE location_zone = p_location_zone
      AND is_available = TRUE
      AND is_active = TRUE;
    
    -- Return count (0 if none available)
    RETURN IFNULL(v_count, 0);
END$

DELIMITER ;