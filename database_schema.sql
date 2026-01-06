CREATE TABLE locations (
    location_id SERIAL PRIMARY KEY,
    city VARCHAR(50) NOT NULL,
    district VARCHAR(50),
    street VARCHAR(100),
    postal_code VARCHAR(10) NOT NULL
);

CREATE TABLE clients (
    client_id SERIAL PRIMARY KEY,
    last_name VARCHAR(50) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    middle_name VARCHAR(50),
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(50) NOT NULL UNIQUE,
    client_type VARCHAR(20) NOT NULL,
    budget NUMERIC(14, 2) NOT NULL,
    CONSTRAINT proper_client_email CHECK (email ~* '^[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'),
    CONSTRAINT chk_client_type CHECK (client_type IN ('покупець', 'орендар', 'продавець')),
    CONSTRAINT chk_client_budget CHECK (budget > 0)
);

CREATE TABLE agents (
    agent_id SERIAL PRIMARY KEY,
    last_name VARCHAR(50) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    middle_name VARCHAR(50),
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(50) NOT NULL UNIQUE,
    experience_years INTEGER NOT NULL,
    commission_rate NUMERIC(5, 2) NOT NULL,
    CONSTRAINT proper_agent_email CHECK (email ~* '^[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'),
    CONSTRAINT chk_agent_experience CHECK (experience_years >= 0),
    CONSTRAINT chk_agent_commission CHECK (commission_rate >= 0 AND commission_rate <= 100)
);

CREATE TABLE properties (
    property_id SERIAL PRIMARY KEY,
    address_line VARCHAR(255) NOT NULL,
    property_type VARCHAR(20) NOT NULL,
    area_sqm NUMERIC (10, 2) NOT NULL,
    room_count INTEGER NOT NULL,
    price NUMERIC(14, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'доступно',
    description TEXT,
    location_id INTEGER NOT NULL,
    CONSTRAINT chk_property_type CHECK (property_type IN ('квартира', 'будинок', 'офіс')),
    CONSTRAINT chk_property_area CHECK (area_sqm > 0),
    CONSTRAINT chk_property_rooms CHECK (room_count >= 0),
    CONSTRAINT chk_property_price CHECK (price > 0),
    CONSTRAINT chk_property_status CHECK (status IN ('продано', 'в оренді', 'доступно')),
    CONSTRAINT fk_properties_location FOREIGN KEY (location_id) REFERENCES locations (location_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE deals (
    deal_id SERIAL PRIMARY KEY,
    deal_date DATE NOT NULL DEFAULT CURRENT_DATE,
    deal_type VARCHAR(20) NOT NULL,
    amount NUMERIC(14, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'в процесі',
    client_id INTEGER NOT NULL,
    agent_id INTEGER NOT NULL,
    property_id INTEGER NOT NULL,
    CONSTRAINT chk_deal_type CHECK (deal_type IN ('купівля', 'оренда')),
    CONSTRAINT chk_deal_amount CHECK (amount > 0),
    CONSTRAINT chk_deal_status CHECK (status IN ('в процесі', 'завершено')),
    CONSTRAINT fk_deals_client FOREIGN KEY (client_id) REFERENCES clients (client_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_deals_agent FOREIGN KEY (agent_id) REFERENCES agents (agent_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_deals_property FOREIGN KEY (property_id) REFERENCES properties (property_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE campaigns (
    campaign_id SERIAL PRIMARY KEY,
    campaign_name VARCHAR(100) NOT NULL UNIQUE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    budget NUMERIC(14, 2) NOT NULL,
    description TEXT,
    CONSTRAINT chk_campaign_dates CHECK (end_date > start_date),
    CONSTRAINT chk_campaign_budget CHECK (budget >= 0)
);

CREATE TABLE campaign_properties (
    campaign_id INTEGER NOT NULL,
    property_id INTEGER NOT NULL,
    PRIMARY KEY (campaign_id, property_id),
    CONSTRAINT fk_cp_campaign FOREIGN KEY (campaign_id) REFERENCES campaigns (campaign_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_cp_property FOREIGN KEY (property_id) REFERENCES properties (property_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX idx_properties_price ON properties(price);
CREATE INDEX idx_properties_status ON properties(status);
CREATE INDEX idx_deals_date ON deals(deal_date);
CREATE INDEX idx_clients_lastname ON clients(last_name);

CREATE OR REPLACE FUNCTION check_deal_date_func()
RETURNS trigger AS $$
BEGIN
    IF NEW.deal_date > CURRENT_DATE THEN
        RAISE EXCEPTION 'Помилка: Дата угоди не може бути у майбутньому!';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_deal_date
BEFORE INSERT OR UPDATE ON deals
FOR EACH ROW
EXECUTE FUNCTION check_deal_date_func();

CREATE OR REPLACE FUNCTION update_property_status_func()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.deal_type = 'купівля' THEN
        UPDATE properties SET status = 'продано' WHERE property_id = NEW.property_id;
    ELSEIF NEW.deal_type = 'оренда' THEN
        UPDATE properties SET status = 'в оренді' WHERE property_id = NEW.property_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_property_status
AFTER INSERT ON deals
FOR EACH ROW
EXECUTE FUNCTION update_property_status_func();

CREATE OR REPLACE VIEW agent_performance_view AS
SELECT
    a.last_name || ' ' || a.first_name AS agent_name,
    COUNT(d.deal_id) AS deals_count,
    COALESCE(SUM(d.amount), 0) AS total_sales
FROM agents a
JOIN deals d ON a.agent_id = d.agent_id
GROUP BY a.agent_id, a.last_name, a.first_name
ORDER BY total_sales DESC;

CREATE OR REPLACE VIEW available_properties_view AS
SELECT
    p.property_id,
    l.city,
    l.district,
    p.address_line,
    p.property_type,
    p.area_sqm,
    p.price
FROM properties p
JOIN locations l ON p.location_id = l.location_id
WHERE p.status = 'доступно';
