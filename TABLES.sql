-- Create database
DROP DATABASE IF EXISTS restaurant_db;
CREATE DATABASE restaurant_db;
USE restaurant_db;

-- ============================================
-- 1. EMPLOYEE TABLES (Overlapping - Lattice)
-- ============================================

CREATE TABLE EMPLOYEE (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone_number VARCHAR(12) NOT NULL,
    email VARCHAR(100) NOT NULL,
    hire_date DATE NOT NULL,
    hourly_wage DECIMAL(10,2) NOT NULL,
    status ENUM('Active', 'Inactive', 'On Leave') NOT NULL DEFAULT 'Active',
    CONSTRAINT chk_wage CHECK (hourly_wage >= 0)
);

CREATE TABLE CASHIER (
    employee_id INT PRIMARY KEY,
    register_number INT NOT NULL,
    cash_handling_certified BOOLEAN NOT NULL DEFAULT FALSE,
    FOREIGN KEY (employee_id) REFERENCES EMPLOYEE(employee_id) ON DELETE CASCADE
);

CREATE TABLE WAITER (
    employee_id INT PRIMARY KEY,
    assigned_section VARCHAR(20),
    total_tips DECIMAL(10,2) DEFAULT 0.00,
    tables_served_count INT DEFAULT 0,
    FOREIGN KEY (employee_id) REFERENCES EMPLOYEE(employee_id) ON DELETE CASCADE,
    CONSTRAINT chk_tips CHECK (total_tips >= 0),
    CONSTRAINT chk_tables CHECK (tables_served_count >= 0)
);

CREATE TABLE CHEF (
    employee_id INT PRIMARY KEY,
    specialty VARCHAR(50),
    certification_level ENUM('Junior Chef', 'Senior Chef', 'Sous Chef', 'Head Chef'),
    years_experience INT,
    FOREIGN KEY (employee_id) REFERENCES EMPLOYEE(employee_id) ON DELETE CASCADE,
    CONSTRAINT chk_experience CHECK (years_experience >= 0)
);

CREATE TABLE MANAGER (
    employee_id INT PRIMARY KEY,
    department ENUM('Front-of-House', 'Kitchen', 'General'),
    management_level ENUM('Shift Manager', 'Assistant Manager', 'General Manager'),
    office_extension VARCHAR(10),
    FOREIGN KEY (employee_id) REFERENCES EMPLOYEE(employee_id) ON DELETE CASCADE
);

-- ============================================
-- 2. CUSTOMER TABLE
-- ============================================

CREATE TABLE CUSTOMER (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone_number VARCHAR(12) NOT NULL UNIQUE,
    email VARCHAR(100),
    registration_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 3. MENU ITEM TABLE (Disjoint - Single Table)
-- ============================================

CREATE TABLE MENUITEM (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    preparation_time INT NOT NULL,
    availability_status ENUM('Available', 'Unavailable', 'Seasonal') NOT NULL DEFAULT 'Available',
    calories INT,
    category_type ENUM('Appetizer', 'MainCourse', 'Beverage') NOT NULL,
    
    -- Appetizer attributes
    serving_size ENUM('Small', 'Medium', 'Large', 'Shareable'),
    spice_level ENUM('None', 'Mild', 'Medium', 'Hot', 'Extra Hot'),
    
    -- MainCourse attributes
    protein_type ENUM('Beef', 'Chicken', 'Fish', 'Pork', 'Vegetarian', 'Vegan'),
    includes_side BOOLEAN,
    portion_size ENUM('Regular', 'Large'),
    
    -- Beverage attributes
    volume INT,
    is_alcoholic BOOLEAN,
    is_refillable BOOLEAN,
    
    CONSTRAINT chk_price CHECK (price > 0),
    CONSTRAINT chk_prep_time CHECK (preparation_time > 0),
    CONSTRAINT chk_calories CHECK (calories >= 0),
    CONSTRAINT chk_volume CHECK (volume > 0 OR volume IS NULL)
);

-- ============================================
-- 4. DIETARY TAGS (Multi-valued Attribute)
-- ============================================

CREATE TABLE DIETARY_TAG (
    item_id INT,
    tag_name ENUM('Vegetarian', 'Vegan', 'Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Halal', 'Kosher', 'Low-Calorie', 'Spicy'),
    PRIMARY KEY (item_id, tag_name),
    FOREIGN KEY (item_id) REFERENCES MENUITEM(item_id) ON DELETE CASCADE
);

-- ============================================
-- 5. PAYMENT TABLE (Disjoint - Single Table)
-- ============================================

CREATE TABLE PAYMENT (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    payment_datetime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount_paid DECIMAL(10,2) NOT NULL,
    tip_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    payment_status ENUM('Pending', 'Completed', 'Failed', 'Refunded') NOT NULL DEFAULT 'Pending',
    cashier_id INT NOT NULL,
    customer_id INT,
    payment_type ENUM('Cash', 'Card') NOT NULL,
    
    -- Cash payment attributes
    amount_tendered DECIMAL(10,2),
    change_given DECIMAL(10,2),
    
    -- Card payment attributes
    card_type ENUM('Visa', 'Mastercard', 'American Express', 'Discover'),
    last_four_digits CHAR(4),
    auth_code VARCHAR(20),
    transaction_id VARCHAR(50),
    
    FOREIGN KEY (cashier_id) REFERENCES CASHIER(employee_id),
    FOREIGN KEY (customer_id) REFERENCES CUSTOMER(customer_id) ON DELETE SET NULL,
    CONSTRAINT chk_amount CHECK (amount_paid >= 0),
    CONSTRAINT chk_tip CHECK (tip_amount >= 0),
    CONSTRAINT chk_tendered CHECK (amount_tendered >= amount_paid OR amount_tendered IS NULL),
    CONSTRAINT chk_change CHECK (change_given >= 0 OR change_given IS NULL)
);

-- ============================================
-- 6. ORDER TABLE
-- ============================================

CREATE TABLE ORDER_TABLE (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    payment_id INT NOT NULL UNIQUE,
    waiter_id INT,
    order_datetime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_type ENUM('DineIn', 'Takeout') NOT NULL,
    table_number INT,
    num_guests INT,
    pickup_time DATETIME,
    subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    order_status ENUM('Pending', 'In-Progress', 'Ready', 'Completed', 'Cancelled') NOT NULL DEFAULT 'Pending',
    special_notes TEXT,
    
    FOREIGN KEY (payment_id) REFERENCES PAYMENT(payment_id) ON DELETE RESTRICT,
    FOREIGN KEY (waiter_id) REFERENCES WAITER(employee_id) ON DELETE SET NULL,
    CONSTRAINT chk_subtotal CHECK (subtotal >= 0),
    CONSTRAINT chk_tax CHECK (tax_amount >= 0),
    CONSTRAINT chk_total CHECK (total_amount >= 0),
    CONSTRAINT chk_table CHECK (table_number > 0 OR table_number IS NULL),
    CONSTRAINT chk_guests CHECK (num_guests > 0 OR num_guests IS NULL)
);

-- ============================================
-- 7. ORDER_MENUITEM (Junction Table - M:N)
-- ============================================

CREATE TABLE ORDER_MENUITEM (
    order_id INT,
    item_id INT,
    quantity INT NOT NULL,
    special_instructions TEXT,
    unit_price_at_order_time DECIMAL(10,2) NOT NULL,
    line_total DECIMAL(10,2) NOT NULL,
    
    PRIMARY KEY (order_id, item_id),
    FOREIGN KEY (order_id) REFERENCES ORDER_TABLE(order_id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES MENUITEM(item_id),
    CONSTRAINT chk_quantity CHECK (quantity > 0),
    CONSTRAINT chk_unit_price CHECK (unit_price_at_order_time > 0),
    CONSTRAINT chk_line_total CHECK (line_total >= 0)
);

-- ============================================
-- Create Indexes for Performance
-- ============================================

CREATE INDEX idx_customer_phone ON CUSTOMER(phone_number);
CREATE INDEX idx_order_datetime ON ORDER_TABLE(order_datetime);
CREATE INDEX idx_order_status ON ORDER_TABLE(order_status);
CREATE INDEX idx_payment_datetime ON PAYMENT(payment_datetime);
CREATE INDEX idx_menuitem_availability ON MENUITEM(availability_status);
CREATE INDEX idx_employee_status ON EMPLOYEE(status);

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Show all tables
SHOW TABLES;

-- Show table structures
-- DESCRIBE EMPLOYEE;
-- DESCRIBE MENUITEM;
-- DESCRIBE PAYMENT;
-- DESCRIBE ORDER_TABLE;
-- DESCRIBE ORDER_MENUITEM;

SELECT 'Database and tables created successfully!' AS Status;