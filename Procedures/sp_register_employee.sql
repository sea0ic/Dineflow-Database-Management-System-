use dineflow;
DELIMITER $$
CREATE PROCEDURE sp_register_employee(
    IN p_first_name VARCHAR(50),
    IN p_last_name VARCHAR(50),
    IN p_phone_number VARCHAR(15),
    IN p_email VARCHAR(100),
    IN p_employee_role ENUM('CASHIER', 'CHEF', 'WAITER', 'MANAGER'),
    IN p_password VARCHAR(255),
    OUT p_employee_id INT,
    OUT p_result_message VARCHAR(255)
)
BEGIN
    DECLARE v_existing_phone INT DEFAULT 0;
    DECLARE v_existing_email INT DEFAULT 0;
    DECLARE v_password_hash CHAR(64);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_employee_id = NULL;
        SET p_result_message = 'Error: Failed to register employee.';
    END;
    
    START TRANSACTION;
    
    -- Check if phone already exists
    SELECT COUNT(*) INTO v_existing_phone
    FROM employee
    WHERE phone_number = p_phone_number;
    
    -- Check if email already exists
    SELECT COUNT(*) INTO v_existing_email
    FROM employee
    WHERE email = p_email;
    
    IF v_existing_phone > 0 THEN
        SET p_employee_id = NULL;
        SET p_result_message = 'Error: Phone number already registered.';
        ROLLBACK;
        
    ELSEIF v_existing_email > 0 THEN
        SET p_employee_id = NULL;
        SET p_result_message = 'Error: Email already registered.';
        ROLLBACK;
        
    ELSEIF p_phone_number NOT REGEXP '^[0-9]{10,15}$' THEN
        SET p_employee_id = NULL;
        SET p_result_message = 'Error: Phone must be 10-15 digits.';
        ROLLBACK;
        
    ELSE
        -- Hash the password
        SET v_password_hash = SHA2(p_password, 256);
        
        -- Insert into EMPLOYEE table
        INSERT INTO employee (
            first_name, last_name, phone_number, email,
            hire_date, employment_status, employee_role,
            password_hash
        ) VALUES (
            p_first_name, p_last_name, p_phone_number, p_email,
            CURDATE(), 'ACTIVE', p_employee_role,
            v_password_hash
        );
        
        SET p_employee_id = LAST_INSERT_ID();
        
        -- Insert into role-specific table based on employee_role
        CASE p_employee_role
            WHEN 'CASHIER' THEN
                INSERT INTO cashier (cashier_id) VALUES (p_employee_id);
                
            WHEN 'CHEF' THEN
                INSERT INTO chef (chef_id, specialty) VALUES (p_employee_id, 'GENERAL');
                
            WHEN 'WAITER' THEN
                INSERT INTO waiter (waiter_id, max_tables) VALUES (p_employee_id, 6);
                
            WHEN 'MANAGER' THEN
                INSERT INTO manager (manager_id, authorization_level) 
                VALUES (p_employee_id, 'SHIFT_MANAGER');
        END CASE;
        
        SET p_result_message = CONCAT('Success: Employee registered with ID ', p_employee_id);
        COMMIT;
    END IF;
END$$

DELIMITER ;