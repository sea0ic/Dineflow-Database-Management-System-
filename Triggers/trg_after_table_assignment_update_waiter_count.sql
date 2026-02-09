DELIMITER $$

CREATE TRIGGER trg_after_table_assignment_update_waiter_count
AFTER UPDATE ON restaurant_table
FOR EACH ROW
BEGIN
    DECLARE v_max_tables INT;
    DECLARE v_current_count INT;
    
    -- CASE 1: New waiter assigned (was NULL, now has waiter)
    IF OLD.assigned_waiter_id IS NULL AND NEW.assigned_waiter_id IS NOT NULL THEN
        
        -- Get waiter's current count and max
        SELECT current_table_count, max_tables 
        INTO v_current_count, v_max_tables
        FROM waiter
        WHERE waiter_id = NEW.assigned_waiter_id;
        
        -- Validate capacity (should be checked in application, but enforce here too)
        IF v_current_count >= v_max_tables THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Waiter has reached maximum table capacity';
        END IF;
        
        -- Increment waiter's table count
        UPDATE waiter
        SET current_table_count = current_table_count + 1
        WHERE waiter_id = NEW.assigned_waiter_id;
        
    END IF;
    
    -- CASE 2: Waiter unassigned (had waiter, now NULL)
    IF OLD.assigned_waiter_id IS NOT NULL AND NEW.assigned_waiter_id IS NULL THEN
        
        -- Decrement old waiter's table count
        UPDATE waiter
        SET current_table_count = GREATEST(0, current_table_count - 1)
        WHERE waiter_id = OLD.assigned_waiter_id;
        
    END IF;
    
    -- CASE 3: Waiter reassigned (changed from one waiter to another)
    IF OLD.assigned_waiter_id IS NOT NULL 
       AND NEW.assigned_waiter_id IS NOT NULL 
       AND OLD.assigned_waiter_id != NEW.assigned_waiter_id THEN
        
        -- Decrement old waiter's count
        UPDATE waiter
        SET current_table_count = GREATEST(0, current_table_count - 1)
        WHERE waiter_id = OLD.assigned_waiter_id;
        
        -- Get new waiter's capacity
        SELECT current_table_count, max_tables 
        INTO v_current_count, v_max_tables
        FROM waiter
        WHERE waiter_id = NEW.assigned_waiter_id;
        
        -- Validate capacity
        IF v_current_count >= v_max_tables THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'New waiter has reached maximum table capacity';
        END IF;
        
        -- Increment new waiter's count
        UPDATE waiter
        SET current_table_count = current_table_count + 1
        WHERE waiter_id = NEW.assigned_waiter_id;
        
    END IF;
END$$
DELIMITER ;