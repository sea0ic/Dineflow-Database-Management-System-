USE restaurant_db;
DELIMITER $$

-- ============================================
-- PROCEDURE 1: Assign_Waiter_To_Order
-- Purpose: Assign a waiter to an existing dine-in order
-- Inputs: 
--   p_order_id - the order to assign
--   p_waiter_id - the waiter to assign
-- ============================================

DROP PROCEDURE IF EXISTS Assign_Waiter_To_Order$$

CREATE PROCEDURE Assign_Waiter_To_Order(
    IN p_order_id INT,
    IN p_waiter_id INT
)
BEGIN
    DECLARE v_order_type VARCHAR(10);
    DECLARE v_waiter_exists INT;
    
    SELECT COUNT(*)
    INTO v_waiter_exists
    FROM WAITER w
    INNER JOIN EMPLOYEE e ON w.employee_id = e.employee_id
    WHERE w.employee_id = p_waiter_id AND e.status = 'Active';
    
    IF v_waiter_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Waiter does not exist or is not active';
    END IF;
    
    SELECT order_type
    INTO v_order_type
    FROM ORDER_TABLE
    WHERE order_id = p_order_id;
    
    IF v_order_type != 'DineIn' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Can only assign waiter to dine-in orders';
    END IF;
    
    UPDATE ORDER_TABLE
    SET waiter_id = p_waiter_id
    WHERE order_id = p_order_id;
    
    UPDATE WAITER
    SET tables_served_count = tables_served_count + 1
    WHERE employee_id = p_waiter_id;
    
    SELECT CONCAT('Waiter ', p_waiter_id, ' assigned to order ', p_order_id) AS Result;
END$$

-- ============================================
-- PROCEDURE 2: Update_Order_Status
-- Purpose: Change order status with validation
-- Inputs:
--   p_order_id - the order to update
--   p_new_status - the new status
-- ============================================

DROP PROCEDURE IF EXISTS Update_Order_Status$$

CREATE PROCEDURE Update_Order_Status(
    IN p_order_id INT,
    IN p_new_status VARCHAR(20)
)
BEGIN
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_valid_transition BOOLEAN DEFAULT FALSE;
    
    SELECT order_status
    INTO v_current_status
    FROM ORDER_TABLE
    WHERE order_id = p_order_id;
    
    
    IF v_current_status = 'Pending' AND p_new_status IN ('In-Progress', 'Cancelled') THEN
        SET v_valid_transition = TRUE;
    ELSEIF v_current_status = 'In-Progress' AND p_new_status IN ('Ready', 'Cancelled') THEN
        SET v_valid_transition = TRUE;
    ELSEIF v_current_status = 'Ready' AND p_new_status IN ('Completed', 'Cancelled') THEN
        SET v_valid_transition = TRUE;
    ELSEIF p_new_status = 'Cancelled' THEN
        SET v_valid_transition = TRUE;
    END IF;
    
    IF NOT v_valid_transition THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid status transition';
    END IF;
    
    -- Update status
    UPDATE ORDER_TABLE
    SET order_status = p_new_status
    WHERE order_id = p_order_id;
    
    SELECT CONCAT('Order ', p_order_id, ' status updated to ', p_new_status) AS Result;
END$$

-- ============================================
-- PROCEDURE 3: Generate_Daily_Sales_Report
-- Purpose: Generate sales summary for a specific date
-- Input: p_report_date - the date to report on
-- ============================================

DROP PROCEDURE IF EXISTS Generate_Daily_Sales_Report$$

CREATE PROCEDURE Generate_Daily_Sales_Report(
    IN p_report_date DATE
)
BEGIN
    SELECT 
        p_report_date AS Report_Date,
        COUNT(o.order_id) AS Total_Orders,
        COALESCE(SUM(o.total_amount), 0.00) AS Total_Revenue,
        COALESCE(AVG(o.total_amount), 0.00) AS Average_Order_Value,
        COALESCE(SUM(p.tip_amount), 0.00) AS Total_Tips,
        SUM(CASE WHEN p.payment_type = 'Cash' THEN 1 ELSE 0 END) AS Cash_Payments,
        SUM(CASE WHEN p.payment_type = 'Card' THEN 1 ELSE 0 END) AS Card_Payments,
        SUM(CASE WHEN o.order_type = 'DineIn' THEN 1 ELSE 0 END) AS DineIn_Orders,
        SUM(CASE WHEN o.order_type = 'Takeout' THEN 1 ELSE 0 END) AS Takeout_Orders
    FROM ORDER_TABLE o
    INNER JOIN PAYMENT p ON o.payment_id = p.payment_id
    WHERE DATE(o.order_datetime) = p_report_date
    AND o.order_status = 'Completed';
    
    SELECT 
        m.item_name AS Item_Name,
        m.category_type AS Category,
        SUM(om.quantity) AS Total_Quantity_Sold,
        COALESCE(SUM(om.line_total), 0.00) AS Total_Revenue
    FROM ORDER_MENUITEM om
    INNER JOIN MENUITEM m ON om.item_id = m.item_id
    INNER JOIN ORDER_TABLE o ON om.order_id = o.order_id
    WHERE DATE(o.order_datetime) = p_report_date
    AND o.order_status = 'Completed'
    GROUP BY m.item_id, m.item_name, m.category_type
    ORDER BY Total_Quantity_Sold DESC
    LIMIT 10;
END$$

-- ============================================
-- PROCEDURE 4: Process_Payment_And_Create_Order
-- Purpose: THE MAIN PROCEDURE - Process payment and create order atomically
-- This is the CORE business logic!
-- Inputs:
--   p_customer_id - customer making purchase (can be NULL for walk-in)
--   p_cashier_id - cashier processing payment
--   p_payment_type - 'Cash' or 'Card'
--   p_amount_paid - amount customer is paying
--   p_tip_amount - tip amount (default 0)
--   p_order_type - 'DineIn' or 'Takeout'
--   p_table_number - table number (for dine-in, NULL for takeout)
--   p_num_guests - number of guests (for dine-in)
--   p_pickup_time - pickup time (for takeout)
--   -- Cash payment specific
--   p_amount_tendered - for cash payments
--   -- Card payment specific
--   p_card_type - for card payments
--   p_last_four - last 4 digits
--   p_auth_code - authorization code
-- Outputs:
--   Returns the new order_id and payment_id
-- ============================================

DROP PROCEDURE IF EXISTS Process_Payment_And_Create_Order$$

CREATE PROCEDURE Process_Payment_And_Create_Order(
    IN p_customer_id INT,
    IN p_cashier_id INT,
    IN p_payment_type VARCHAR(10),
    IN p_amount_paid DECIMAL(10,2),
    IN p_tip_amount DECIMAL(10,2),
    IN p_order_type VARCHAR(10),
    IN p_table_number INT,
    IN p_num_guests INT,
    IN p_pickup_time DATETIME,
    IN p_amount_tendered DECIMAL(10,2),
    IN p_card_type VARCHAR(20),
    IN p_last_four CHAR(4),
    IN p_auth_code VARCHAR(20),
    OUT p_new_order_id INT,
    OUT p_new_payment_id INT
)
BEGIN
    DECLARE v_change DECIMAL(10,2);
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM CASHIER WHERE employee_id = p_cashier_id) THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid cashier ID';
    END IF;
    
    IF p_amount_paid <= 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment amount must be positive';
    END IF;
    
    IF p_payment_type = 'Cash' THEN
        IF p_amount_tendered < p_amount_paid THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Amount tendered must be >= amount paid';
        END IF;
        SET v_change = Calculate_Change(p_amount_tendered, p_amount_paid);
    END IF;
    
    INSERT INTO PAYMENT (
        payment_datetime,
        amount_paid,
        tip_amount,
        payment_status,
        cashier_id,
        customer_id,
        payment_type,
        amount_tendered,
        change_given,
        card_type,
        last_four_digits,
        auth_code,
        transaction_id
    ) VALUES (
        NOW(),
        p_amount_paid,
        COALESCE(p_tip_amount, 0.00),
        'Completed',
        p_cashier_id,
        p_customer_id,
        p_payment_type,
        p_amount_tendered,
        v_change,
        p_card_type,
        p_last_four,
        p_auth_code,
        UUID() 
    );
    
    SET p_new_payment_id = LAST_INSERT_ID();
    
    INSERT INTO ORDER_TABLE (
        payment_id,
        order_datetime,
        order_type,
        table_number,
        num_guests,
        pickup_time,
        subtotal,
        tax_amount,
        total_amount,
        order_status
    ) VALUES (
        p_new_payment_id,
        NOW(),
        p_order_type,
        p_table_number,
        p_num_guests,
        p_pickup_time,
        0.00, 
        0.00,
        0.00,
        'Pending'
    );
    
    SET p_new_order_id = LAST_INSERT_ID();
    
    COMMIT;
    
    SELECT 
        p_new_order_id AS Order_ID,
        p_new_payment_id AS Payment_ID,
        'Payment processed and order created successfully' AS Status;
END$$

-- ============================================
-- PROCEDURE 5: Add_Item_To_Order
-- Purpose: Add a menu item to an existing order
-- Inputs:
--   p_order_id - the order to add to
--   p_item_id - the menu item to add
--   p_quantity - quantity to add
--   p_special_instructions - any special requests
-- ============================================

DROP PROCEDURE IF EXISTS Add_Item_To_Order$$

CREATE PROCEDURE Add_Item_To_Order(
    IN p_order_id INT,
    IN p_item_id INT,
    IN p_quantity INT,
    IN p_special_instructions TEXT
)
BEGIN
    DECLARE v_item_price DECIMAL(10,2);
    DECLARE v_line_total DECIMAL(10,2);
    DECLARE v_new_subtotal DECIMAL(10,2);
    DECLARE v_new_tax DECIMAL(10,2);
    DECLARE v_new_total DECIMAL(10,2);
    
    START TRANSACTION;
    
    IF NOT Check_MenuItem_Available(p_item_id) THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Menu item is not available';
    END IF;
    
    SELECT price
    INTO v_item_price
    FROM MENUITEM
    WHERE item_id = p_item_id;
    
    SET v_line_total = v_item_price * p_quantity;
    
    INSERT INTO ORDER_MENUITEM (
        order_id,
        item_id,
        quantity,
        special_instructions,
        unit_price_at_order_time,
        line_total
    ) VALUES (
        p_order_id,
        p_item_id,
        p_quantity,
        p_special_instructions,
        v_item_price,
        v_line_total
    );
    
    SET v_new_subtotal = Calculate_Order_Subtotal(p_order_id);
    SET v_new_tax = Calculate_Tax(v_new_subtotal);
    SET v_new_total = v_new_subtotal + v_new_tax;
    
    UPDATE ORDER_TABLE
    SET subtotal = v_new_subtotal,
        tax_amount = v_new_tax,
        total_amount = v_new_total
    WHERE order_id = p_order_id;
    
    COMMIT;
    
    SELECT 
        p_order_id AS Order_ID,
        p_item_id AS Item_Added,
        p_quantity AS Quantity,
        v_line_total AS Line_Total,
        v_new_total AS New_Order_Total,
        'Item added successfully' AS Status;
END$$

DELIMITER ;

SELECT 'All stored procedures created successfully!' AS Status;

-- Show all procedures
SHOW PROCEDURE STATUS WHERE Db = 'restaurant_db';