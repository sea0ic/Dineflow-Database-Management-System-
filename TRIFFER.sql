USE restaurant_db;
DELIMITER $$

-- ============================================
-- TRIGGER 1: Before_OrderMenuItem_Insert_Check_Availability
-- Purpose: Prevent ordering unavailable menu items
-- Event: BEFORE INSERT on ORDER_MENUITEM
-- Logic: Check if menu item is available, raise error if not
-- ============================================

DROP TRIGGER IF EXISTS Before_OrderMenuItem_Insert_Check_Availability$$

CREATE TRIGGER Before_OrderMenuItem_Insert_Check_Availability
BEFORE INSERT ON ORDER_MENUITEM
FOR EACH ROW
BEGIN
    DECLARE v_available BOOLEAN;
    
    SET v_available = Check_MenuItem_Available(NEW.item_id);
    
    IF NOT v_available THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot order unavailable menu item';
    END IF;
END$$

-- ============================================
-- TRIGGER 2: After_OrderMenuItem_Insert_Update_Totals
-- Purpose: Automatically recalculate order totals when item added
-- Event: AFTER INSERT on ORDER_MENUITEM
-- Logic: Recalculate subtotal, tax, and total for the order
-- ============================================

DROP TRIGGER IF EXISTS After_OrderMenuItem_Insert_Update_Totals$$

CREATE TRIGGER After_OrderMenuItem_Insert_Update_Totals
AFTER INSERT ON ORDER_MENUITEM
FOR EACH ROW
BEGIN
    DECLARE v_subtotal DECIMAL(10,2);
    DECLARE v_tax DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,2);
    
    SET v_subtotal = Calculate_Order_Subtotal(NEW.order_id);
    
    SET v_tax = Calculate_Tax(v_subtotal);
    
    SET v_total = v_subtotal + v_tax;
    
    UPDATE ORDER_TABLE
    SET subtotal = v_subtotal,
        tax_amount = v_tax,
        total_amount = v_total
    WHERE order_id = NEW.order_id;
END$$

-- ============================================
-- TRIGGER 3: After_OrderMenuItem_Update_Update_Totals
-- Purpose: Recalculate totals when order item is modified
-- Event: AFTER UPDATE on ORDER_MENUITEM
-- Logic: Same as insert - recalculate all totals
-- ============================================

DROP TRIGGER IF EXISTS After_OrderMenuItem_Update_Update_Totals$$

CREATE TRIGGER After_OrderMenuItem_Update_Update_Totals
AFTER UPDATE ON ORDER_MENUITEM
FOR EACH ROW
BEGIN
    DECLARE v_subtotal DECIMAL(10,2);
    DECLARE v_tax DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,2);
    
    SET v_subtotal = Calculate_Order_Subtotal(NEW.order_id);
    
    SET v_tax = Calculate_Tax(v_subtotal);
    
    SET v_total = v_subtotal + v_tax;
    
    UPDATE ORDER_TABLE
    SET subtotal = v_subtotal,
        tax_amount = v_tax,
        total_amount = v_total
    WHERE order_id = NEW.order_id;
END$$

-- ============================================
-- TRIGGER 4: After_OrderMenuItem_Delete_Update_Totals
-- Purpose: Recalculate totals when item removed from order
-- Event: AFTER DELETE on ORDER_MENUITEM
-- Logic: Recalculate remaining totals
-- ============================================

DROP TRIGGER IF EXISTS After_OrderMenuItem_Delete_Update_Totals$$

CREATE TRIGGER After_OrderMenuItem_Delete_Update_Totals
AFTER DELETE ON ORDER_MENUITEM
FOR EACH ROW
BEGIN
    DECLARE v_subtotal DECIMAL(10,2);
    DECLARE v_tax DECIMAL(10,2);
    DECLARE v_total DECIMAL(10,2);
    
    SET v_subtotal = Calculate_Order_Subtotal(OLD.order_id);
    
    SET v_tax = Calculate_Tax(v_subtotal);
    
    SET v_total = v_subtotal + v_tax;
    
    UPDATE ORDER_TABLE
    SET subtotal = v_subtotal,
        tax_amount = v_tax,
        total_amount = v_total
    WHERE order_id = OLD.order_id;
END$$

-- ============================================
-- TRIGGER 5: After_Payment_Insert_Update_Waiter_Tips
-- Purpose: Automatically add tips to waiter's total when payment includes tip
-- Event: AFTER INSERT on PAYMENT
-- Logic: If payment has tip and order has waiter, add to waiter's tips
-- ============================================

DROP TRIGGER IF EXISTS After_Payment_Insert_Update_Waiter_Tips$$

CREATE TRIGGER After_Payment_Insert_Update_Waiter_Tips
AFTER INSERT ON PAYMENT
FOR EACH ROW
BEGIN
    DECLARE v_waiter_id INT;
    
    IF NEW.payment_status = 'Completed' AND NEW.tip_amount > 0 THEN
        
        SELECT waiter_id INTO v_waiter_id
        FROM ORDER_TABLE
        WHERE payment_id = NEW.payment_id;
        
        IF v_waiter_id IS NOT NULL THEN
            UPDATE WAITER
            SET total_tips = total_tips + NEW.tip_amount
            WHERE employee_id = v_waiter_id;
        END IF;
    END IF;
END$$

-- ============================================
-- TRIGGER 6: Before_Order_Status_Update_Validate
-- Purpose: Validate order status transitions
-- Event: BEFORE UPDATE on ORDER_TABLE
-- Logic: Prevent invalid status changes
-- ============================================

DROP TRIGGER IF EXISTS Before_Order_Status_Update_Validate$$

CREATE TRIGGER Before_Order_Status_Update_Validate
BEFORE UPDATE ON ORDER_TABLE
FOR EACH ROW
BEGIN
    DECLARE v_valid_transition BOOLEAN DEFAULT FALSE;
    
    IF OLD.order_status != NEW.order_status THEN
        
        IF OLD.order_status = 'Pending' AND NEW.order_status IN ('In-Progress', 'Cancelled') THEN
            SET v_valid_transition = TRUE;
        ELSEIF OLD.order_status = 'In-Progress' AND NEW.order_status IN ('Ready', 'Cancelled') THEN
            SET v_valid_transition = TRUE;
        ELSEIF OLD.order_status = 'Ready' AND NEW.order_status IN ('Completed', 'Cancelled') THEN
            SET v_valid_transition = TRUE;
        ELSEIF NEW.order_status = 'Cancelled' THEN
            SET v_valid_transition = TRUE;
        ELSEIF OLD.order_status = 'Completed' AND NEW.order_status = 'Completed' THEN
            SET v_valid_transition = TRUE;
        END IF;
        
        IF NOT v_valid_transition THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid order status transition';
        END IF;
    END IF;
END$$

-- ============================================
-- TRIGGER 7: Before_Payment_Insert_Validate
-- Purpose: Validate payment data before insertion
-- Event: BEFORE INSERT on PAYMENT
-- Logic: Check payment type specific requirements
-- ============================================

DROP TRIGGER IF EXISTS Before_Payment_Insert_Validate$$

CREATE TRIGGER Before_Payment_Insert_Validate
BEFORE INSERT ON PAYMENT
FOR EACH ROW
BEGIN
    IF NEW.payment_type = 'Cash' THEN
        IF NEW.amount_tendered IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cash payment must have amount_tendered';
        END IF;
        
        IF NEW.amount_tendered < NEW.amount_paid THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Amount tendered must be >= amount paid';
        END IF;
        
        IF NEW.change_given IS NULL THEN
            SET NEW.change_given = Calculate_Change(NEW.amount_tendered, NEW.amount_paid);
        END IF;
    END IF;
    
    IF NEW.payment_type = 'Card' THEN
        IF NEW.card_type IS NULL OR NEW.last_four_digits IS NULL OR NEW.auth_code IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Card payment must have card_type, last_four_digits, and auth_code';
        END IF;
    END IF;
END$$

-- ============================================
-- TRIGGER 8: Before_Order_Insert_Validate
-- Purpose: Validate order data before insertion
-- Event: BEFORE INSERT on ORDER_TABLE
-- Logic: Check order type specific requirements
-- ============================================

DROP TRIGGER IF EXISTS Before_Order_Insert_Validate$$

CREATE TRIGGER Before_Order_Insert_Validate
BEFORE INSERT ON ORDER_TABLE
FOR EACH ROW
BEGIN
    IF NEW.order_type = 'DineIn' THEN
        IF NEW.table_number IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'DineIn order must have table_number';
        END IF;
    END IF;
    
    IF NEW.order_type = 'Takeout' THEN
        IF NEW.pickup_time IS NULL THEN
            SET NEW.pickup_time = DATE_ADD(NOW(), INTERVAL 20 MINUTE);
        END IF;
    END IF;
END$$

DELIMITER ;

-- ============================================
-- VERIFY TRIGGERS
-- ============================================

SELECT 'All triggers created successfully!' AS Status;

SHOW TRIGGERS FROM restaurant_db;