use dineflow;
DELIMITER $$

CREATE PROCEDURE sp_add_menu_item(
    IN p_item_name VARCHAR(100),
    IN p_description TEXT,
    IN p_category ENUM('APPETIZER', 'MAIN', 'DESSERT', 'BEVERAGE'),
    IN p_price DECIMAL(10,2),
    IN p_prep_time_minutes INT,
    IN p_created_by_manager_id INT,
    OUT p_item_id INT,
    OUT p_result_message VARCHAR(255)
)
BEGIN
    DECLARE v_manager_exists INT DEFAULT 0;
    DECLARE v_duplicate_item INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_item_id = NULL;
        SET p_result_message = 'Error: Failed to add menu item.';
    END;
    
    START TRANSACTION;
    
    -- Verify manager exists
    SELECT COUNT(*) INTO v_manager_exists
    FROM manager m
    JOIN employee e ON m.manager_id = e.employee_id
    WHERE m.manager_id = p_created_by_manager_id
      AND e.employment_status = 'ACTIVE';
    
    IF v_manager_exists = 0 THEN
        SET p_item_id = NULL;
        SET p_result_message = 'Error: Manager not found or inactive.';
        ROLLBACK;
        
    ELSEIF p_price <= 0 THEN
        SET p_item_id = NULL;
        SET p_result_message = 'Error: Price must be greater than 0.';
        ROLLBACK;
        
    ELSEIF p_prep_time_minutes < 5 OR p_prep_time_minutes > 20 THEN
        SET p_item_id = NULL;
        SET p_result_message = 'Error: Prep time must be between 5 and 20 minutes.';
        ROLLBACK;
        
    ELSE
        -- Check for duplicate (same name in same category)
        SELECT COUNT(*) INTO v_duplicate_item
        FROM menu_item
        WHERE item_name = p_item_name 
          AND category = p_category
          AND is_active = TRUE;
        
        IF v_duplicate_item > 0 THEN
            SET p_item_id = NULL;
            SET p_result_message = 'Error: Item already exists in this category.';
            ROLLBACK;
        ELSE
            INSERT INTO menu_item (
                item_name, description, category, price,
                prep_time_minutes, is_available, is_active,
                created_by
            ) VALUES (
                p_item_name, p_description, p_category, p_price,
                p_prep_time_minutes, TRUE, TRUE,
                p_created_by_manager_id
            );
            
            SET p_item_id = LAST_INSERT_ID();
            SET p_result_message = CONCAT('Success: Menu item added with ID ', p_item_id);
            COMMIT;
        END IF;
    END IF;
END$$

DELIMITER ;