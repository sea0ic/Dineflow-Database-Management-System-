USE restaurant_db;
DELIMITER $$
-- ============================================
-- FUNCTION 1: Calculate_Order_Subtotal
-- Purpose: Calculate the subtotal for an order
-- Input: order_id (INT)
-- Returns: DECIMAL(10,2) - the subtotal amount
-- ============================================

DROP FUNCTION IF EXISTS Calculate_Order_Subtotal$$

CREATE FUNCTION Calculate_Order_Subtotal(p_order_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_subtotal DECIMAL(10,2);
    
    SELECT COALESCE(SUM(line_total), 0.00)
    INTO v_subtotal
    FROM ORDER_MENUITEM
    WHERE order_id = p_order_id;
    
    RETURN v_subtotal;
END$$

-- ============================================
-- FUNCTION 2: Calculate_Tax
-- Purpose: Calculate tax amount for a given subtotal
-- Input: subtotal (DECIMAL)
-- Returns: DECIMAL(10,2) - tax amount (8% rate)
-- ============================================

DROP FUNCTION IF EXISTS Calculate_Tax$$

CREATE FUNCTION Calculate_Tax(p_subtotal DECIMAL(10,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
    RETURN ROUND(p_subtotal * 0.08, 2);
END$$

-- ============================================
-- FUNCTION 3: Calculate_Change
-- Purpose: Calculate change for cash payment
-- Input: amount_tendered, amount_paid
-- Returns: DECIMAL(10,2) - change to give back
-- ============================================

DROP FUNCTION IF EXISTS Calculate_Change$$

CREATE FUNCTION Calculate_Change(
    p_tendered DECIMAL(10,2),
    p_paid DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_change DECIMAL(10,2);
    
    SET v_change = p_tendered - p_paid;
    
    IF v_change < 0 THEN
        SET v_change = 0.00;
    END IF;
    
    RETURN v_change;
END$$

-- ============================================
-- FUNCTION 4: Check_MenuItem_Available
-- Purpose: Check if a menu item is available for ordering
-- Input: item_id (INT)
-- Returns: BOOLEAN (1 = available, 0 = not available)
-- ============================================

DROP FUNCTION IF EXISTS Check_MenuItem_Available$$

CREATE FUNCTION Check_MenuItem_Available(p_item_id INT)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_status VARCHAR(20);
    
    -- Get availability status
    SELECT availability_status
    INTO v_status
    FROM MENUITEM
    WHERE item_id = p_item_id;
    
    IF v_status = 'Available' THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END$$

-- ============================================
-- FUNCTION 5: Get_Waiter_Total_Tips
-- Purpose: Get total tips earned by a waiter
-- Input: waiter_id (INT)
-- Returns: DECIMAL(10,2) - total tips
-- ============================================

DROP FUNCTION IF EXISTS Get_Waiter_Total_Tips$$

CREATE FUNCTION Get_Waiter_Total_Tips(p_waiter_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_tips DECIMAL(10,2);
    
    SELECT COALESCE(total_tips, 0.00)
    INTO v_tips
    FROM WAITER
    WHERE employee_id = p_waiter_id;
    
    RETURN v_tips;
END$$

DELIMITER ;


SELECT 'All functions created successfully!' AS Status;