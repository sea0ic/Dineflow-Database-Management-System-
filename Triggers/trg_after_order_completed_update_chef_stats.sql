DELIMITER $$
CREATE TRIGGER trg_after_order_completed_update_chef_stats
AFTER UPDATE ON customer_order
FOR EACH ROW
BEGIN
    DECLARE v_avg_prep_time DECIMAL(5,2);
    
    -- Only process when order is completed
    IF NEW.status = 'COMPLETED' AND OLD.status != 'COMPLETED' AND NEW.chef_id IS NOT NULL THEN
        
        -- Increment total orders prepared
        UPDATE chef
        SET total_orders_prepared = total_orders_prepared + 1
        WHERE chef_id = NEW.chef_id;
        
        -- Increment SLA violations if exceeded 30 minutes
        IF NEW.actual_prep_time > 30 THEN
            UPDATE chef
            SET orders_exceeding_sla = orders_exceeding_sla + 1
            WHERE chef_id = NEW.chef_id;
        END IF;
        
        -- Recalculate average prep time using function
        SELECT GetChefAveragePrepTime(NEW.chef_id) INTO v_avg_prep_time;
        
        UPDATE chef
        SET average_prep_time = v_avg_prep_time
        WHERE chef_id = NEW.chef_id;
        
        -- Log if flagged for review
        IF NEW.is_flagged_for_review = TRUE THEN
            INSERT INTO audit_log (
                log_type,
                employee_id,
                action_description,
                table_affected,
                record_id
            ) VALUES (
                'OVERRIDE',
                NEW.chef_id,
                CONCAT('Order ', NEW.order_number, ' exceeded SLA: ', NEW.actual_prep_time, ' minutes'),
                'customer_order',
                NEW.order_id
            );
        END IF;
        
    END IF;
END$$

DELIMITER ;