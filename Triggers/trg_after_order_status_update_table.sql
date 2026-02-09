DELIMITER $$
CREATE TRIGGER trg_after_order_status_update_table
AFTER UPDATE ON customer_order
FOR EACH ROW
BEGIN
    -- Only process dine-in orders with tables
    IF NEW.table_id IS NOT NULL AND NEW.order_type = 'DINE_IN' THEN        
        -- CASE 1: Order is queued (payment completed) - Mark table occupied
        IF NEW.status = 'QUEUED' AND OLD.status = 'PENDING' THEN
            UPDATE restaurant_table
            SET is_available = FALSE,
                current_order_id = NEW.order_id,
                occupied_since = CURRENT_TIMESTAMP
            WHERE table_id = NEW.table_id;            
            INSERT INTO audit_log (
                log_type,
                action_description,
                table_affected,
                record_id
            ) VALUES (
                'OVERRIDE',
                CONCAT('Table ', NEW.table_id, ' occupied by order ', NEW.order_number),
                'restaurant_table',
                NEW.table_id
            );
        END IF;
        
        -- CASE 2: Order cancelled or refunded - Release table
        IF NEW.status IN ('CANCELLED', 'REFUNDED') AND OLD.status NOT IN ('CANCELLED', 'REFUNDED') THEN
            UPDATE restaurant_table
            SET is_available = TRUE,
                current_order_id = NULL,
                occupied_since = NULL
            WHERE table_id = NEW.table_id;
            
            INSERT INTO audit_log (
                log_type,
                action_description,
                table_affected,
                record_id
            ) VALUES (
                'OVERRIDE',
                CONCAT('Table ', NEW.table_id, ' released (order ', NEW.order_number, ' ', NEW.status, ')'),
                'restaurant_table',
                NEW.table_id
            );
        END IF;
        
    END IF;
END$$

DELIMITER ;