CREATE DATABASE dineflow, 

-- EMPLOYEE HIERARCHY
-- Employee supertype table
CREATE TABLE employee (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone_number VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    hire_date DATE NOT NULL,
    employment_status ENUM('ACTIVE', 'ON_LEAVE', 'TERMINATED') NOT NULL DEFAULT 'ACTIVE',
    employee_role ENUM('CASHIER', 'CHEF', 'WAITER', 'MANAGER') NOT NULL,
    password_hash CHAR(64) NOT NULL COMMENT 'SHA-256 hashed password',
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT chk_employee_phone CHECK (phone_number REGEXP '^[0-9]{10,15}$'),
    CONSTRAINT chk_employee_email CHECK (email REGEXP '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$')
) ENGINE=InnoDB COMMENT='Employee supertype - all staff members';

-- Cashier subtype table
CREATE TABLE cashier (
    cashier_id INT PRIMARY KEY,
    shift_start_time TIME NULL,
    shift_end_time TIME NULL,
    total_orders_processed INT NOT NULL DEFAULT 0,
    average_order_processing_time DECIMAL(5,2) NULL COMMENT 'In minutes',
    last_shift_date DATE NULL,
    
    -- Foreign key to employee supertype
    CONSTRAINT fk_cashier_employee FOREIGN KEY (cashier_id) 
        REFERENCES employee(employee_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_cashier_orders CHECK (total_orders_processed >= 0),
    CONSTRAINT chk_cashier_avg_time CHECK (average_order_processing_time IS NULL OR average_order_processing_time > 0)
) ENGINE=InnoDB COMMENT='Cashier subtype - order entry and payment processing';

-- Chef subtype table
CREATE TABLE chef (
    chef_id INT PRIMARY KEY,
    specialty ENUM('GRILL', 'FRYER', 'ASSEMBLY', 'DESSERT', 'GENERAL') NOT NULL DEFAULT 'GENERAL',
    total_orders_prepared INT NOT NULL DEFAULT 0,
    average_prep_time DECIMAL(5,2) NULL COMMENT 'In minutes',
    orders_exceeding_sla INT NOT NULL DEFAULT 0 COMMENT 'Orders over 30 minutes',
    
    -- Foreign key to employee supertype
    CONSTRAINT fk_chef_employee FOREIGN KEY (chef_id) 
        REFERENCES employee(employee_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_chef_orders CHECK (total_orders_prepared >= 0),
    CONSTRAINT chk_chef_sla CHECK (orders_exceeding_sla >= 0)
) ENGINE=InnoDB COMMENT='Chef subtype - food preparation';

-- Waiter subtype table
CREATE TABLE waiter (
    waiter_id INT PRIMARY KEY,
    max_tables INT NOT NULL DEFAULT 6,
    current_table_count INT NOT NULL DEFAULT 0,
    total_deliveries INT NOT NULL DEFAULT 0,
    average_delivery_time DECIMAL(5,2) NULL COMMENT 'In minutes',
    
    -- Foreign key to employee supertype
    CONSTRAINT fk_waiter_employee FOREIGN KEY (waiter_id) 
        REFERENCES employee(employee_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_waiter_max_tables CHECK (max_tables > 0 AND max_tables <= 10),
    CONSTRAINT chk_waiter_current_tables CHECK (current_table_count >= 0 AND current_table_count <= max_tables),
    CONSTRAINT chk_waiter_deliveries CHECK (total_deliveries >= 0)
) ENGINE=InnoDB COMMENT='Waiter subtype - order delivery and table management';

-- Manager subtype table
CREATE TABLE manager (
    manager_id INT PRIMARY KEY,
    authorization_level ENUM('SHIFT_MANAGER', 'GENERAL_MANAGER', 'OWNER') NOT NULL DEFAULT 'SHIFT_MANAGER',
    total_refunds_approved INT NOT NULL DEFAULT 0,
    total_refunds_denied INT NOT NULL DEFAULT 0,
    
    -- Foreign key to employee supertype
    CONSTRAINT fk_manager_employee FOREIGN KEY (manager_id) 
        REFERENCES employee(employee_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_manager_refunds_approved CHECK (total_refunds_approved >= 0),
    CONSTRAINT chk_manager_refunds_denied CHECK (total_refunds_denied >= 0)
) ENGINE=InnoDB COMMENT='Manager subtype - oversight and approvals';

--  CUSTOMER AND LOYALTY

-- Customer table
CREATE TABLE customer (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    phone_number VARCHAR(15) UNIQUE NULL COMMENT 'NULL for guest customers',
    phone_number_hash CHAR(64) NULL COMMENT 'Hashed for privacy',
    first_name VARCHAR(50) NULL,
    last_name VARCHAR(50) NULL,
    total_stars INT NOT NULL DEFAULT 0,
    total_lifetime_orders INT NOT NULL DEFAULT 0,
    registration_date DATE NOT NULL,
    last_order_date DATE NULL,
    is_vip BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'TRUE when total_stars >= 100',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT chk_customer_phone CHECK (phone_number IS NULL OR phone_number REGEXP '^[0-9]{10}$'),
    CONSTRAINT chk_customer_stars CHECK (total_stars >= 0),
    CONSTRAINT chk_customer_orders CHECK (total_lifetime_orders >= 0)
) ENGINE=InnoDB COMMENT='Customer information and loyalty tracking';

-- Loyalty star transaction table (weak entity )
CREATE TABLE loyalty_star_transaction (
    star_transaction_id INT AUTO_INCREMENT,
    customer_id INT NOT NULL,
    transaction_type ENUM('EARNED', 'REDEEMED', 'REVERSED', 'ADJUSTED') NOT NULL,
    star_amount INT NOT NULL COMMENT 'Positive for earned, negative for redeemed',
    balance_before INT NOT NULL,
    balance_after INT NOT NULL,
    order_id INT NULL,
    transaction_id INT NULL,
    refund_id INT NULL,
    discount_percentage DECIMAL(5,2) NULL COMMENT 'If redeemed: 5.00, 10.00, 15.00, or 20.00',
    transaction_date DATE NOT NULL,
    transaction_time TIME NOT NULL,
    notes TEXT NULL,
    created_by INT NULL COMMENT 'Employee ID for manual adjustments',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (star_transaction_id, customer_id),
    
    -- Foreign keys
    CONSTRAINT fk_star_customer FOREIGN KEY (customer_id) 
        REFERENCES customer(customer_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_star_created_by FOREIGN KEY (created_by)
        REFERENCES employee(employee_id) ON DELETE SET NULL ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_star_balance CHECK (balance_before >= 0 AND balance_after >= 0),
    CONSTRAINT chk_star_discount CHECK (discount_percentage IS NULL OR discount_percentage IN (5.00, 10.00, 15.00, 20.00))
) ENGINE=InnoDB COMMENT='Audit trail for loyalty star transactions';

-- MENU MANAGEMENT

-- Menu item table
CREATE TABLE menu_item (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    category ENUM('APPETIZER', 'MAIN', 'DESSERT', 'BEVERAGE') NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    cost DECIMAL(10,2) NULL COMMENT 'Cost of goods for margin analysis',
    prep_time_minutes INT NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Soft delete flag',
    image_url VARCHAR(255) NULL,
    allergen_info VARCHAR(255) NULL,
    calories INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT NOT NULL,
    
    -- Foreign key
    CONSTRAINT fk_menu_created_by FOREIGN KEY (created_by)
        REFERENCES manager(manager_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_menu_price CHECK (price > 0),
    CONSTRAINT chk_menu_prep_time CHECK (prep_time_minutes >= 5 AND prep_time_minutes <= 20),
    CONSTRAINT chk_menu_calories CHECK (calories IS NULL OR calories >= 0),
    
    -- Unique constraint
    CONSTRAINT uq_menu_name_category UNIQUE (item_name, category)
) ENGINE=InnoDB COMMENT='Menu items available for purchase';

-- TABLE MANAGEMENT

-- Table table
CREATE TABLE restaurant_table (
    table_id INT AUTO_INCREMENT PRIMARY KEY,
    table_number INT NOT NULL UNIQUE,
    capacity INT NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    current_order_id INT NULL,
    assigned_waiter_id INT NULL,
    occupied_since TIMESTAMP NULL,
    last_cleaned TIMESTAMP NULL,
    location_zone ENUM('FRONT', 'MIDDLE', 'BACK', 'PATIO') NOT NULL DEFAULT 'MIDDLE',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'FALSE for maintenance',
    
    CONSTRAINT fk_table_waiter FOREIGN KEY (assigned_waiter_id)
        REFERENCES waiter(waiter_id) ON DELETE SET NULL ON UPDATE CASCADE,
    
    CONSTRAINT chk_table_number CHECK (table_number >= 1 AND table_number <= 20),
    CONSTRAINT chk_table_capacity CHECK (capacity IN (2, 4, 6))
) ENGINE=InnoDB COMMENT='Restaurant tables for dine-in service';


-- ORDER MANAGEMENT

-- Order table (central entity)
CREATE TABLE customer_order (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    order_number VARCHAR(20) NOT NULL UNIQUE COMMENT 'Format: YYYYMMDD-####',
    customer_id INT NULL COMMENT 'NULL for guest orders',
    cashier_id INT NOT NULL,
    chef_id INT NULL COMMENT 'Assigned when cooking starts',
    waiter_id INT NULL COMMENT 'For dine-in orders only',
    table_id INT NULL COMMENT 'NULL for takeout',
    order_date DATE NOT NULL,
    order_time TIME NOT NULL,
    order_type ENUM('DINE_IN', 'TAKEOUT') NOT NULL,
    status ENUM('PENDING', 'QUEUED', 'IN_PROCESS', 'COMPLETED', 'DELIVERED', 'CANCELLED', 'REFUNDED') NOT NULL DEFAULT 'PENDING',
    status_updated_at TIMESTAMP NULL,
    special_instructions TEXT NULL,
    estimated_wait_time INT NOT NULL DEFAULT 30 COMMENT 'In minutes',
    actual_prep_time INT NULL COMMENT 'Calculated: completed - queued',
    subtotal DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    tax_amount DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    stars_earned INT NOT NULL DEFAULT 1,
    stars_redeemed INT NOT NULL DEFAULT 0,
    is_flagged_for_review BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    queued_at TIMESTAMP NULL,
    in_process_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    delivered_at TIMESTAMP NULL,
    related_order_id INT NULL COMMENT 'For split payment linking',
    
    -- Foreign keys
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_order_cashier FOREIGN KEY (cashier_id)
        REFERENCES cashier(cashier_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_order_chef FOREIGN KEY (chef_id)
        REFERENCES chef(chef_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_order_waiter FOREIGN KEY (waiter_id)
        REFERENCES waiter(waiter_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_order_table FOREIGN KEY (table_id)
        REFERENCES restaurant_table(table_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_order_related FOREIGN KEY (related_order_id)
        REFERENCES customer_order(order_id) ON DELETE SET NULL ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_order_amounts CHECK (total_amount = subtotal - discount_amount + tax_amount),
    CONSTRAINT chk_order_tax CHECK (tax_amount = ROUND((subtotal - discount_amount) * 0.10, 2)),
    CONSTRAINT chk_order_dine_in CHECK (order_type = 'TAKEOUT' OR table_id IS NOT NULL),
    CONSTRAINT chk_order_wait_time CHECK (estimated_wait_time > 0 AND estimated_wait_time <= 60),
    CONSTRAINT chk_order_stars_earned CHECK (stars_earned >= 0),
    CONSTRAINT chk_order_stars_redeemed CHECK (stars_redeemed >= 0),
    CONSTRAINT chk_order_subtotal CHECK (subtotal >= 5.00),
    CONSTRAINT chk_order_special_instructions CHECK (special_instructions IS NULL OR LENGTH(special_instructions) <= 500)
) ENGINE=InnoDB COMMENT='Customer orders - central transaction entity';

-- foreign key from restaurant_table to customer_order
ALTER TABLE restaurant_table
    ADD CONSTRAINT fk_table_current_order FOREIGN KEY (current_order_id)
        REFERENCES customer_order(order_id) ON DELETE SET NULL ON UPDATE CASCADE;

-- Order item table (associative entity - M:N relationship)
CREATE TABLE order_item (
    order_id INT NOT NULL,
    item_id INT NOT NULL,
    line_number INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL COMMENT 'Price snapshot at order time',
    special_instructions VARCHAR(200) NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (order_id, item_id, line_number),
    
    -- Foreign keys
    CONSTRAINT fk_orderitem_order FOREIGN KEY (order_id)
        REFERENCES customer_order(order_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_orderitem_item FOREIGN KEY (item_id)
        REFERENCES menu_item(item_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_orderitem_quantity CHECK (quantity > 0 AND quantity <= 99),
    CONSTRAINT chk_orderitem_subtotal CHECK (subtotal = quantity * unit_price),
    CONSTRAINT chk_orderitem_special_instructions CHECK (special_instructions IS NULL OR LENGTH(special_instructions) <= 200)
) ENGINE=InnoDB COMMENT='Order line items - links orders to menu items';

-- PAYMENT AND TRANSACTIONS

-- Transaction table
CREATE TABLE payment_transaction (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL UNIQUE COMMENT 'One transaction per order',
    transaction_date DATE NOT NULL,
    transaction_time TIME NOT NULL,
    payment_method ENUM('CASH', 'CREDIT', 'DEBIT') NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    tax_amount DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    amount_tendered DECIMAL(10,2) NULL COMMENT 'For cash payments only',
    change_amount DECIMAL(10,2) NULL COMMENT 'For cash payments only',
    card_last_four CHAR(4) NULL COMMENT 'Last 4 digits only - PCI compliance',
    card_authorization_code VARCHAR(20) NULL,
    card_type ENUM('VISA', 'MASTERCARD', 'AMEX', 'DISCOVER') NULL,
    transaction_status ENUM('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED') NOT NULL DEFAULT 'PENDING',
    processed_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign keys
    CONSTRAINT fk_transaction_order FOREIGN KEY (order_id)
        REFERENCES customer_order(order_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_transaction_cashier FOREIGN KEY (processed_by)
        REFERENCES cashier(cashier_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_transaction_amount CHECK (total_amount > 0),
    CONSTRAINT chk_transaction_cash CHECK (
        payment_method != 'CASH' OR 
        (amount_tendered IS NOT NULL AND change_amount IS NOT NULL AND amount_tendered >= total_amount)
    ),
    CONSTRAINT chk_transaction_card CHECK (
        payment_method = 'CASH' OR 
        (card_last_four IS NOT NULL AND card_authorization_code IS NOT NULL)
    ),
    CONSTRAINT chk_transaction_change CHECK (
        change_amount IS NULL OR change_amount = amount_tendered - total_amount
    )
) ENGINE=InnoDB COMMENT='Payment transactions - financial records';

-- Add foreign keys to loyalty_star_transaction for order and transaction
ALTER TABLE loyalty_star_transaction
    ADD CONSTRAINT fk_star_order FOREIGN KEY (order_id)
        REFERENCES customer_order(order_id) ON DELETE SET NULL ON UPDATE CASCADE,
    ADD CONSTRAINT fk_star_transaction FOREIGN KEY (transaction_id)
        REFERENCES payment_transaction(transaction_id) ON DELETE SET NULL ON UPDATE CASCADE;

-- REFUND MANAGEMENT

-- Refund table
CREATE TABLE refund (
    refund_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL UNIQUE COMMENT 'One refund per order',
    transaction_id INT NOT NULL,
    refund_date DATE NOT NULL,
    refund_time TIME NOT NULL,
    refund_amount DECIMAL(10,2) NOT NULL,
    refund_reason TEXT NOT NULL,
    reason_category ENUM('EXCESSIVE_WAIT', 'WRONG_ORDER', 'QUALITY_ISSUE', 'CUSTOMER_REQUEST', 'OTHER') NULL,
    requested_by INT NOT NULL,
    approved_by INT NOT NULL,
    approval_status ENUM('PENDING', 'APPROVED', 'DENIED') NOT NULL DEFAULT 'PENDING',
    approval_date DATE NULL,
    refund_method ENUM('ORIGINAL_PAYMENT', 'CASH', 'STORE_CREDIT') NULL,
    stars_reversed INT NOT NULL DEFAULT 0,
    manager_notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP NULL,
    
    -- Foreign keys
    CONSTRAINT fk_refund_order FOREIGN KEY (order_id)
        REFERENCES customer_order(order_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_refund_transaction FOREIGN KEY (transaction_id)
        REFERENCES payment_transaction(transaction_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_refund_requested_by FOREIGN KEY (requested_by)
        REFERENCES cashier(cashier_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_refund_approved_by FOREIGN KEY (approved_by)
        REFERENCES manager(manager_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Constraints
    CONSTRAINT chk_refund_amount CHECK (refund_amount > 0),
    CONSTRAINT chk_refund_reason CHECK (LENGTH(refund_reason) >= 10),
    CONSTRAINT chk_refund_stars CHECK (stars_reversed >= 0)
) ENGINE=InnoDB COMMENT='Refund records requiring manager approval';

-- Add foreign key to loyalty_star_transaction for refund
ALTER TABLE loyalty_star_transaction
    ADD CONSTRAINT fk_star_refund FOREIGN KEY (refund_id)
        REFERENCES refund(refund_id) ON DELETE SET NULL ON UPDATE CASCADE;

-- SYSTEM TABLES

-- Audit log table
CREATE TABLE audit_log (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    log_type ENUM('LOGIN', 'LOGOUT', 'REFUND', 'MENU_CHANGE', 'OVERRIDE', 'ERROR') NOT NULL,
    employee_id INT NULL,
    action_description TEXT NOT NULL,
    table_affected VARCHAR(50) NULL,
    record_id INT NULL,
    ip_address VARCHAR(45) NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign key
    CONSTRAINT fk_audit_employee FOREIGN KEY (employee_id)
        REFERENCES employee(employee_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='System-wide audit trail for security and compliance';

-- System configuration table
CREATE TABLE system_config (
    config_key VARCHAR(50) PRIMARY KEY,
    config_value TEXT NOT NULL,
    data_type ENUM('STRING', 'INTEGER', 'DECIMAL', 'BOOLEAN') NOT NULL,
    description TEXT NULL,
    updated_by INT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Foreign key
    CONSTRAINT fk_config_updated_by FOREIGN KEY (updated_by)
        REFERENCES manager(manager_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='System-wide configuration parameters';

-- INDEXES FOR PERFORMANCE

-- Customer indexes
CREATE INDEX idx_customer_phone ON customer(phone_number);
CREATE INDEX idx_customer_registration_date ON customer(registration_date);

-- Employee indexes
CREATE INDEX idx_employee_role ON employee(employee_role);
CREATE INDEX idx_employee_status ON employee(employment_status);

-- Order indexes
CREATE INDEX idx_order_date ON customer_order(order_date);
CREATE INDEX idx_order_status ON customer_order(status);
CREATE INDEX idx_order_customer ON customer_order(customer_id);
CREATE INDEX idx_order_cashier ON customer_order(cashier_id);
CREATE INDEX idx_order_created_at ON customer_order(created_at);
CREATE INDEX idx_order_number ON customer_order(order_number);

-- Transaction indexes
CREATE INDEX idx_transaction_date ON payment_transaction(transaction_date);
CREATE INDEX idx_transaction_method ON payment_transaction(payment_method);
CREATE INDEX idx_transaction_status ON payment_transaction(transaction_status);

-- Menu item indexes
CREATE INDEX idx_menu_category ON menu_item(category);
CREATE INDEX idx_menu_available ON menu_item(is_available);

-- Table indexes
CREATE INDEX idx_table_available ON restaurant_table(is_available);
CREATE INDEX idx_table_waiter ON restaurant_table(assigned_waiter_id);

-- Loyalty transaction indexes
CREATE INDEX idx_star_customer ON loyalty_star_transaction(customer_id);
CREATE INDEX idx_star_date ON loyalty_star_transaction(transaction_date);

-- Audit log indexes
CREATE INDEX idx_audit_employee ON audit_log(employee_id);
CREATE INDEX idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX idx_audit_type ON audit_log(log_type);

-- INITIAL CONFIGURATION DATA

-- Insert system configuration
INSERT INTO system_config (config_key, config_value, data_type, description) VALUES
    ('tax_rate', '0.10', 'DECIMAL', 'Sales tax rate (10%)'),
    ('order_sla_minutes', '30', 'INTEGER', 'Service level agreement for order completion'),
    ('max_items_per_order', '50', 'INTEGER', 'Maximum items allowed per order'),
    ('min_order_value', '5.00', 'DECIMAL', 'Minimum order subtotal in USD'),
    ('max_waiter_tables', '6', 'INTEGER', 'Maximum tables per waiter'),
    ('star_10_discount', '5.00', 'DECIMAL', '10-star discount percentage'),
    ('star_25_discount', '10.00', 'DECIMAL', '25-star discount percentage'),
    ('star_50_discount', '15.00', 'DECIMAL', '50-star discount percentage'),
    ('star_100_discount', '20.00', 'DECIMAL', '100-star discount percentage'),
    ('business_hours_open', '10:00:00', 'STRING', 'Restaurant opening time'),
    ('business_hours_close', '22:00:00', 'STRING', 'Restaurant closing time');

-- VIEWS FOR COMMON QUERIES

-- View: Current active orders with full details
CREATE VIEW v_active_orders AS
SELECT 
    o.order_id,
    o.order_number,
    o.order_type,
    o.status,
    o.created_at,
    o.total_amount,
    c.first_name AS customer_first_name,
    c.last_name AS customer_last_name,
    c.phone_number AS customer_phone,
    CONCAT(e_cashier.first_name, ' ', e_cashier.last_name) AS cashier_name,
    CONCAT(e_chef.first_name, ' ', e_chef.last_name) AS chef_name,
    CONCAT(e_waiter.first_name, ' ', e_waiter.last_name) AS waiter_name,
    t.table_number,
    TIMESTAMPDIFF(MINUTE, o.created_at, CURRENT_TIMESTAMP) AS elapsed_minutes
FROM customer_order o
LEFT JOIN customer c ON o.customer_id = c.customer_id
LEFT JOIN cashier cash ON o.cashier_id = cash.cashier_id
LEFT JOIN employee e_cashier ON cash.cashier_id = e_cashier.employee_id
LEFT JOIN chef ch ON o.chef_id = ch.chef_id
LEFT JOIN employee e_chef ON ch.chef_id = e_chef.employee_id
LEFT JOIN waiter w ON o.waiter_id = w.waiter_id
LEFT JOIN employee e_waiter ON w.waiter_id = e_waiter.employee_id
LEFT JOIN restaurant_table t ON o.table_id = t.table_id
WHERE o.status NOT IN ('DELIVERED', 'CANCELLED', 'REFUNDED')
ORDER BY o.created_at;

-- View: Daily sales summary
CREATE VIEW v_daily_sales_summary AS
SELECT 
    order_date,
    COUNT(*) AS total_orders,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS average_order_value,
    SUM(CASE WHEN status = 'REFUNDED' THEN 1 ELSE 0 END) AS refunded_orders,
    SUM(CASE WHEN order_type = 'DINE_IN' THEN 1 ELSE 0 END) AS dine_in_orders,
    SUM(CASE WHEN order_type = 'TAKEOUT' THEN 1 ELSE 0 END) AS takeout_orders
FROM customer_order
WHERE status != 'CANCELLED'
GROUP BY order_date
ORDER BY order_date DESC;

-- View: Popular menu items
CREATE VIEW v_popular_menu_items AS
SELECT 
    m.item_id,
    m.item_name,
    m.category,
    m.price,
    COUNT(oi.order_id) AS times_ordered,
    SUM(oi.quantity) AS total_quantity_sold,
    SUM(oi.subtotal) AS total_revenue
FROM menu_item m
JOIN order_item oi ON m.item_id = oi.item_id
JOIN customer_order o ON oi.order_id = o.order_id
WHERE o.status NOT IN ('CANCELLED', 'REFUNDED')
GROUP BY m.item_id, m.item_name, m.category, m.price
ORDER BY times_ordered DESC;

-- View: Employee performance summary
CREATE VIEW v_employee_performance AS
SELECT 
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
    e.employee_role,
    CASE 
        WHEN e.employee_role = 'CASHIER' THEN cash.total_orders_processed
        WHEN e.employee_role = 'CHEF' THEN ch.total_orders_prepared
        WHEN e.employee_role = 'WAITER' THEN w.total_deliveries
        ELSE 0
    END AS total_transactions,
    CASE 
        WHEN e.employee_role = 'CASHIER' THEN cash.average_order_processing_time
        WHEN e.employee_role = 'CHEF' THEN ch.average_prep_time
        WHEN e.employee_role = 'WAITER' THEN w.average_delivery_time
        ELSE NULL
    END AS average_time_minutes
FROM employee e
LEFT JOIN cashier cash ON e.employee_id = cash.cashier_id
LEFT JOIN chef ch ON e.employee_id = ch.chef_id
LEFT JOIN waiter w ON e.employee_id = w.waiter_id
WHERE e.employment_status = 'ACTIVE';

-- View: Customer loyalty statistics
CREATE VIEW v_customer_loyalty_stats AS
SELECT 
    customer_id,
    CONCAT(first_name, ' ', last_name) AS customer_name,
    phone_number,
    total_stars,
    total_lifetime_orders,
    is_vip,
    registration_date,
    last_order_date,
    DATEDIFF(CURRENT_DATE, last_order_date) AS days_since_last_order
FROM customer;
