DELIMITER $$
CREATE FUNCTION IsMenuItemAvailable(p_item_id INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_is_available BOOLEAN;
    DECLARE v_is_active BOOLEAN;
    -- Get item availability status
    SELECT is_available, is_active INTO v_is_available, v_is_active
    FROM menu_item
    WHERE item_id = p_item_id;
    -- Return FALSE if item not found
    IF v_is_available IS NULL THEN
        RETURN FALSE;
    END IF;
    -- Return TRUE only if both available and active
    IF v_is_available = TRUE AND v_is_active = TRUE THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END$$GetChefAveragePrepTime
DELIMITER ;