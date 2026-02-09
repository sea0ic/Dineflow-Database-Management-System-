use dineflow;
DELIMITER $$

CREATE PROCEDURE sp_create_order (
    IN  p_customer_id INT,
    IN  p_cashier_id INT,
    IN  p_table_id INT,
    IN  p_order_type VARCHAR(20),
    IN  p_special_instructions TEXT,
    OUT p_order_id INT,
    OUT p_order_number VARCHAR(20),
    OUT p_result_message VARCHAR(255)
)
proc: BEGIN
    DECLARE v_cashier_exists INT;
    DECLARE v_table_available BOOLEAN;
    DECLARE v_order_count INT;
    DECLARE v_order_num VARCHAR(20);

    -- Diagnostic variables
    DECLARE v_errno INT;
    DECLARE v_msg TEXT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_errno = MYSQL_ERRNO,
            v_msg   = MESSAGE_TEXT;

        ROLLBACK;

        SET p_order_id = NULL;
        SET p_order_number = NULL;
        SET p_result_message = CONCAT(
            'DB ERROR ', v_errno, ': ', v_msg
        );
    END;

    -- Default outputs
    SET p_order_id = NULL;
    SET p_order_number = NULL;
    SET p_result_message = NULL;

    IF p_order_type NOT IN ('DINE_IN', 'TAKEOUT') THEN
        SET p_result_message = 'Error: Invalid order type.';
        LEAVE proc;
    END IF;

    SELECT COUNT(*)
    INTO v_cashier_exists
    FROM cashier c
    JOIN employee e ON e.employee_id = c.cashier_id
    WHERE c.cashier_id = p_cashier_id
      AND e.employment_status = 'ACTIVE';

    IF v_cashier_exists = 0 THEN
        SET p_result_message = 'Error: Cashier not found or inactive.';
        LEAVE proc;
    END IF;

    IF p_order_type = 'DINE_IN' THEN

        IF p_table_id IS NULL THEN
            SET p_result_message = 'Error: Table required for dine-in orders.';
            LEAVE proc;
        END IF;

        SELECT is_available
        INTO v_table_available
        FROM restaurant_table
        WHERE table_id = p_table_id
          AND is_active = TRUE;

        IF v_table_available IS NULL THEN
            SET p_result_message = 'Error: Table not found.';
            LEAVE proc;
        END IF;

        IF v_table_available = FALSE THEN
            SET p_result_message = 'Error: Table is currently occupied.';
            LEAVE proc;
        END IF;

    END IF;
    START TRANSACTION;

    SELECT COUNT(*)
    INTO v_order_count
    FROM customer_order
    WHERE order_date = CURDATE();

    SET v_order_num = CONCAT(
        DATE_FORMAT(CURDATE(), '%Y%m%d'),
        '-',
        LPAD(v_order_count + 1, 4, '0')
    );

    INSERT INTO customer_order (
        order_number,
        customer_id,
        cashier_id,
        table_id,
        order_date,
        order_time,
        order_type,
        status,
        special_instructions,
        subtotal,
        tax_amount,
        total_amount
    )
    VALUES (
        v_order_num,
        p_customer_id,
        p_cashier_id,
        p_table_id,
        CURDATE(),
        CURTIME(),
        p_order_type,
        'PENDING',
        p_special_instructions,
        0.00,
        0.00,
        0.00
    );

    SET p_order_id = LAST_INSERT_ID();
    SET p_order_number = v_order_num;

    IF p_order_type = 'DINE_IN' THEN
        UPDATE restaurant_table
        SET is_available = FALSE,
            current_order_id = p_order_id,
            occupied_since = NOW()
        WHERE table_id = p_table_id;
    END IF;

    COMMIT;

    SET p_result_message = CONCAT(
        'Success: Order ',
        v_order_num,
        ' created.'
    );

END$$

DELIMITER ;
