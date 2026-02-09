DELIMITER $$

CREATE FUNCTION GetChefAveragePrepTime(p_chef_id INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_avg_time DECIMAL(5,2);
    
    -- Calculate average prep time from completed orders
    SELECT AVG(actual_prep_time) INTO v_avg_time
    FROM customer_order
    WHERE chef_id = p_chef_id
      AND status IN ('COMPLETED', 'DELIVERED')
      AND actual_prep_time IS NOT NULL;
    
    -- Return NULL if no completed orders
    IF v_avg_time IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN v_avg_time;
END$$

DELIMITER ;