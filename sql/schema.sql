-- Database schema for the Ames house price analysis (MySQL 8.0+).
-- The notebook creates the database "ames_housing", runs this file and then loads the tables.
-- To run it by hand, first select the database with USE ames_housing

DROP VIEW IF EXISTS valuation_gaps;
DROP TABLE IF EXISTS predictions;
DROP TABLE IF EXISTS houses;
DROP TABLE IF EXISTS segments;
DROP TABLE IF EXISTS neighborhoods;

-- Lookup table: neighbourhood codes from the data and their full names from data_description.txt
CREATE TABLE neighborhoods (
    neighborhood_code VARCHAR(10) PRIMARY KEY,
    neighborhood_name VARCHAR(60) NOT NULL
);

-- Market segments found by K-Means clustering (without using the price)
CREATE TABLE segments (
    segment_id   TINYINT UNSIGNED PRIMARY KEY,
    segment_name VARCHAR(40)      NOT NULL
);

-- One row per sold house in the training data, after cleaning and feature engineering
CREATE TABLE houses (
    house_id          INT UNSIGNED      PRIMARY KEY,   -- Id in the Kaggle data
    neighborhood_code VARCHAR(10)       NOT NULL,
    segment_id        TINYINT UNSIGNED  NOT NULL,
    overall_qual      TINYINT UNSIGNED  NOT NULL,      -- 1 (very poor) to 10 (very excellent)
    total_sf          INT UNSIGNED      NOT NULL,      -- basement + 1st + 2nd floor, sq ft
    house_age         SMALLINT UNSIGNED NOT NULL,      -- years from construction to sale
    total_bathrooms   DECIMAL(3, 1)     NOT NULL,      -- half bathrooms count as 0.5
    garage_cars       TINYINT UNSIGNED  NOT NULL,
    sale_condition    VARCHAR(10)       NOT NULL,      -- Normal, Abnorml, Partial, Family, AdjLand, Alloca
    year_sold         SMALLINT UNSIGNED NOT NULL,
    month_sold        TINYINT UNSIGNED  NOT NULL,
    -- Prices are signed INT on purpose: in MySQL, subtracting two UNSIGNED values
    -- raises an error when the result is negative (sale price below the estimate)
    sale_price        INT               NOT NULL,
    CONSTRAINT fk_houses_neighborhood FOREIGN KEY (neighborhood_code)
        REFERENCES neighborhoods (neighborhood_code),
    CONSTRAINT fk_houses_segment FOREIGN KEY (segment_id) REFERENCES segments (segment_id),
    CONSTRAINT chk_houses_quality CHECK (overall_qual BETWEEN 1 AND 10),
    CONSTRAINT chk_houses_month CHECK (month_sold BETWEEN 1 AND 12),
    CONSTRAINT chk_houses_price CHECK (sale_price > 0)
);

-- Out-of-fold price predictions of the best regression model
-- (each house is predicted by a model that did not see it during training)
CREATE TABLE predictions (
    house_id        INT UNSIGNED PRIMARY KEY,
    predicted_price INT          NOT NULL,
    model_name      VARCHAR(40)  NOT NULL,
    CONSTRAINT fk_predictions_house FOREIGN KEY (house_id) REFERENCES houses (house_id),
    CONSTRAINT chk_predictions_price CHECK (predicted_price > 0)
);

-- Automated valuation: how far each sale price is from the model's estimate.
-- Sales more than 10 percent away from the estimate are flagged for a closer look.
CREATE VIEW valuation_gaps AS
SELECT h.house_id,
       n.neighborhood_name,
       h.sale_condition,
       h.sale_price,
       p.predicted_price,
       ROUND(100 * (h.sale_price - p.predicted_price) / p.predicted_price, 1) AS price_gap_pct,
       CASE
           WHEN h.sale_price > 1.1 * p.predicted_price THEN 'Above estimate'
           WHEN h.sale_price < 0.9 * p.predicted_price THEN 'Below estimate'
           ELSE 'In line'
       END AS valuation
FROM houses h
JOIN predictions p ON p.house_id = h.house_id
JOIN neighborhoods n ON n.neighborhood_code = h.neighborhood_code;
