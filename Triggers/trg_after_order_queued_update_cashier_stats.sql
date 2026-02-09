DELIMITER $$

CREATE TRIGGER trg_after_order_queued_update_cashier_stats
AFTER UPDATE ON customer_order
FOR EACH ROW
BEGIN
    DECLARE v_processing_time DECIMAL(5,2);
    DECLARE v_current_count INT;
    DECLARE v_current_avg DECIMAL(5,2);
    DECLARE v_new_avg DECIMAL(5,2);
    
    -- Only process when order moves from PENDING to QUEUED
    IF NEW.status = 'QUEUED' AND OLD.status = 'PENDING' AND NEW.cashier_id IS NOT NULL THEN
        
        -- Calculate processing time in minutes
        SET v_processing_time = TIMESTAMPDIFF(SECOND, NEW.created_at, NEW.queued_at) / 60.0;
        
        -- Get current cashier stats
        SELECT total_orders_processed, average_order_processing_time
        INTO v_current_count, v_current_avg
        FROM cashier
        WHERE cashier_id = NEW.cashier_id;
        
        -- Handle NULL average (first order)
        IF v_current_avg IS NULL THEN
            SET v_current_avg = 0;
        END IF;
        
        -- Calculate new running average
        SET v_new_avg = ((v_current_avg * v_current_count) + v_processing_time) / (v_current_count + 1);
        
        -- Update cashier performance metrics
        UPDATE cashier
        SET total_orders_processed = total_orders_processed + 1,
            average_order_processing_time = v_new_avg,
            last_shift_date = CURRENT_DATE
        WHERE cashier_id = NEW.cashier_id;
        
    END IF;
END$$

DELIMITER ;