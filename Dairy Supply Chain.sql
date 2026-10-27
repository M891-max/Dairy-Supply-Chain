/* ============================================================
   1. TABLES
   ============================================================ */
CREATE TABLE Suppliers 
(
SupplierID INT PRIMARY KEY,
SupplierCode VARCHAR(10) UNIQUE,
SupplierName VARCHAR(120),
SupplierType VARCHAR(20) CHECK(SupplierType IN ('Dairy Farm','Ingredient','Packaging')),
Governorate VARCHAR(50),
LeadTimeDays TINYINT CHECK(LeadTimeDays > 0),
QualityRating DECIMAL(3,2) CHECK(QualityRating BETWEEN 1.00 AND 5.00),
Status VARCHAR(10) DEFAULT 'Active' CHECK(Status IN ('Active','Inactive'))
);

CREATE TABLE Materials 
(
MaterialID INT PRIMARY KEY,
MaterialCode VARCHAR(12) UNIQUE,
MaterialName VARCHAR(120),
MaterialCategory VARCHAR(30) CHECK(MaterialCategory IN ('Raw Milk','Ingredient','Culture','Fruit Preparation','Flavor','Packaging')),
UOM VARCHAR(10) CHECK(UOM IN ('L','KG','PCS')),
StorageType VARCHAR(15) CHECK(StorageType IN ('Chilled','Frozen','Ambient')),
ShelfLifeDays SMALLINT CHECK(ShelfLifeDays > 0),
StandardCost DECIMAL(12,4) CHECK(StandardCost > 0),
Status VARCHAR(10) DEFAULT 'Active' CHECK(Status IN ('Active','Inactive'))
);

CREATE TABLE Products 
(
ProductID INT PRIMARY KEY,
ProductCode VARCHAR(12) UNIQUE,
ProductName VARCHAR(120),
ProductFamily VARCHAR(30) CHECK(ProductFamily IN ('Set Yoghurt','Stirred Yoghurt','Family Tub')),
Flavor VARCHAR(30) CHECK(Flavor IN ('Plain','Strawberry','Mango','Blueberry','Vanilla')),
PackSizeG SMALLINT CHECK(PackSizeG > 0),
UnitsPerCase SMALLINT CHECK(UnitsPerCase > 0),
TargetPH DECIMAL(3,2) CHECK(TargetPH BETWEEN 4.00 AND 4.80),
ShelfLifeDays SMALLINT CHECK(ShelfLifeDays > 0),
Status VARCHAR(10) DEFAULT 'Active' CHECK(Status IN ('Active','Inactive'))
);

CREATE TABLE ProductionLines 
(
LineID INT PRIMARY KEY,
LineCode VARCHAR(10) UNIQUE,
LineName VARCHAR(80),
RatedCapacityKgPerHour DECIMAL(10,2) CHECK(RatedCapacityKgPerHour > 0),
Status VARCHAR(10) DEFAULT 'Active' CHECK(Status IN ('Active','Inactive'))
);

CREATE TABLE PurchaseOrders
(
POID BIGINT PRIMARY KEY,
PONumber VARCHAR(20) UNIQUE,
SupplierID INT REFERENCES Suppliers(SupplierID),
PODate DATE,
ExpectedDate DATE,
POStatus VARCHAR(15) CHECK(POStatus IN ('Open','Partial','Closed','Cancelled')),
Currency CHAR(3) CHECK(Currency IN ('EGP','USD','EUR')),
FreightCost DECIMAL(12,2) CHECK(FreightCost >= 0),
CHECK(ExpectedDate >= PODate)
);

CREATE TABLE PurchaseOrderLines 
(
POLineID BIGINT PRIMARY KEY,
POID BIGINT REFERENCES PurchaseOrders(POID),
MaterialID INT REFERENCES Materials(MaterialID),
OrderedQty DECIMAL(14,3) CHECK(OrderedQty > 0),
ReceivedQty DECIMAL(14,3) CHECK(ReceivedQty >= 0),
UnitCost DECIMAL(12,4) CHECK(UnitCost > 0),
LineStatus VARCHAR(15) CHECK(LineStatus IN ('Open','Partial','Received','Cancelled')),
UNIQUE (POID, MaterialID)
);

CREATE TABLE ProductionBatches 
(
BatchID BIGINT PRIMARY KEY,
BatchCode VARCHAR(20) UNIQUE,
ProductID INT REFERENCES Products(ProductID),
LineID INT REFERENCES ProductionLines(LineID),
ProductionDate DATE,
PlannedQtyKg DECIMAL(14,2) CHECK(PlannedQtyKg > 0),
ActualQtyKg DECIMAL(14,2) CHECK(ActualQtyKg >= 0),
RejectQtyKg DECIMAL(14,2) CHECK(RejectQtyKg >= 0),
StartDateTime DATETIME2,
EndDateTime DATETIME2,
BatchStatus VARCHAR(15) CHECK(BatchStatus IN ('In Process','Released','On Hold','Rejected')),
CHECK(RejectQtyKg <= ActualQtyKg),
CHECK(EndDateTime > StartDateTime)
);

CREATE TABLE BatchMaterialUsage 
(
UsageID BIGINT PRIMARY KEY,
BatchID BIGINT REFERENCES ProductionBatches(BatchID),
MaterialID INT REFERENCES Materials(MaterialID),
MaterialLotNo VARCHAR(25),
PlannedQty DECIMAL(14,3) CHECK(PlannedQty > 0),
ActualQty DECIMAL(14,3) CHECK(ActualQty >= 0),
WasteQty DECIMAL(14,3) CHECK(WasteQty >= 0),
UnitCost DECIMAL(12,4) CHECK(UnitCost > 0),
UNIQUE (BatchID, MaterialID, MaterialLotNo)
);

CREATE TABLE QualityInspections
(
InspectionID BIGINT PRIMARY KEY,
InspectionType VARCHAR(20) CHECK(InspectionType IN ('IncomingMilk','InProcess','FinishedProduct')),
SupplierID INT REFERENCES Suppliers(SupplierID),
BatchID BIGINT REFERENCES ProductionBatches(BatchID),
InspectionDateTime DATETIME2,
TemperatureC DECIMAL(4,1),
PHValue DECIMAL(4,2) CHECK(PHValue BETWEEN 0 AND 14),
FatPct DECIMAL(4,2) CHECK(FatPct BETWEEN 0 AND 100),
BacteriaCountCFU INT CHECK(BacteriaCountCFU >= 0),
Result VARCHAR(10) CHECK(Result IN ('Pass','Hold','Fail')),
InspectorCode VARCHAR(10),
Notes VARCHAR(200),
CHECK(
(InspectionType = 'IncomingMilk' AND SupplierID IS NOT NULL AND BatchID IS NULL)
OR
(InspectionType IN ('InProcess','FinishedProduct') AND BatchID IS NOT NULL AND SupplierID IS NULL)
)
);

CREATE TABLE Dispatches 
(
DispatchID BIGINT PRIMARY KEY,
DispatchNumber VARCHAR(20) UNIQUE,
BatchID BIGINT REFERENCES ProductionBatches(BatchID),
DispatchDateTime DATETIME2,
DestinationGovernorate VARCHAR(50),
DistributorName VARCHAR(120),
QuantityCases INT CHECK(QuantityCases > 0),
TruckCode VARCHAR(15),
DispatchTemperatureC DECIMAL(4,1),
DeliveryStatus VARCHAR(25) CHECK(DeliveryStatus IN ('Delivered','Returned','RejectedAtDestination'))
);
GO

/* ============================================================
   2. DATA LOAD (one transaction: if anything fails, nothing is kept)
   ============================================================ */
SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRANSACTION;

--1 Suppliers
INSERT INTO Suppliers
(
    SupplierID, SupplierCode, SupplierName, SupplierType,
    Governorate, LeadTimeDays, QualityRating, Status
)
VALUES
(1,'SUP001','Green Valley Dairy Farm','Dairy Farm','Beheira',1,4.72,'Active'),
(2,'SUP002','Delta Milk Cooperative','Dairy Farm','Dakahlia',1,4.55,'Active'),
(3,'SUP003','Nile Meadows Farm','Dairy Farm','Gharbia',1,4.61,'Active'),
(4,'SUP004','Al Safwa Dairy Estate','Dairy Farm','Sharqia',1,4.34,'Active'),
(5,'SUP005','West Delta Milk Farm','Dairy Farm','Beheira',1,4.28,'Active'),
(6,'SUP006','El Wadi Dairy Farm','Dairy Farm','Fayoum',1,4.42,'Active'),
(7,'SUP007','Menoufia Fresh Milk Farm','Dairy Farm','Menoufia',1,4.18,'Active'),
(8,'SUP008','Al Amal Dairy Farm','Dairy Farm','Giza',1,4.11,'Active'),
(9,'SUP009','Beni Suef Milk Producers','Dairy Farm','Beni Suef',1,4.36,'Active'),
(10,'SUP010','Royal Herd Dairy Farm','Dairy Farm','Sharqia',1,4.67,'Active'),
(11,'SUP011','Delta Prime Milk Farm','Dairy Farm','Dakahlia',1,4.52,'Active'),
(12,'SUP012','Al Nour Dairy Farm','Dairy Farm','Gharbia',1,4.09,'Active'),
(13,'SUP013','Harvest Dairy Estate','Dairy Farm','Beheira',1,4.44,'Active'),
(14,'SUP014','Fayoum Dairy Cooperative','Dairy Farm','Fayoum',1,4.03,'Active'),
(15,'SUP015','Eastern Plains Dairy','Dairy Farm','Sharqia',1,4.39,'Active'),
(16,'SUP016','Canal Dairy Farm','Dairy Farm','Ismailia',1,4.22,'Active'),
(17,'SUP017','Upper Nile Dairy Farm','Dairy Farm','Minya',2,3.91,'Active'),
(18,'SUP018','Golden Cow Dairy Farm','Dairy Farm','Menoufia',1,3.84,'Inactive'),

(19,'SUP019','SweetSource Ingredients','Ingredient','Cairo',7,4.58,'Active'),
(20,'SUP020','FermaTech Cultures','Ingredient','Cairo',14,4.79,'Active'),
(21,'SUP021','FruitBlend Egypt','Ingredient','Alexandria',10,4.63,'Active'),
(22,'SUP022','StabilMix Food Solutions','Ingredient','Giza',8,4.41,'Active'),
(23,'SUP023','Delta Dairy Ingredients','Ingredient','Dakahlia',9,4.36,'Active'),
(24,'SUP024','Nile Food Additives','Ingredient','Cairo',11,4.18,'Active'),
(25,'SUP025','Mediterranean Fruit Prep','Ingredient','Alexandria',12,4.47,'Active'),
(26,'SUP026','ProCulture Ingredients','Ingredient','Giza',15,4.74,'Active'),
(27,'SUP027','SugarLine Supply','Ingredient','Gharbia',6,4.21,'Active'),
(28,'SUP028','FoodBase Egypt','Ingredient','Cairo',8,4.05,'Active'),
(29,'SUP029','Prime Dairy Powders','Ingredient','Alexandria',18,4.33,'Active'),
(30,'SUP030','FlavorCraft Egypt','Ingredient','Giza',12,3.88,'Inactive'),

(31,'SUP031','PackForm Egypt','Packaging','10th of Ramadan',7,4.62,'Active'),
(32,'SUP032','Delta Cups Industries','Packaging','Sharqia',6,4.48,'Active'),
(33,'SUP033','FlexSeal Packaging','Packaging','6th of October',8,4.57,'Active'),
(34,'SUP034','CartonWorks Egypt','Packaging','Cairo',5,4.31,'Active'),
(35,'SUP035','Nile Plastics Packaging','Packaging','Qalyubia',7,4.22,'Active'),
(36,'SUP036','Prime Foil Industries','Packaging','Alexandria',9,4.51,'Active'),
(37,'SUP037','SmartPack Solutions','Packaging','Giza',6,4.45,'Active'),
(38,'SUP038','FreshCup Packaging','Packaging','Sharqia',5,4.28,'Active'),
(39,'SUP039','BoxLine Industries','Packaging','Gharbia',6,4.17,'Active'),
(40,'SUP040','Delta Label & Pack','Packaging','Dakahlia',7,4.13,'Active'),
(41,'SUP041','ColdChain Pack Egypt','Packaging','Cairo',10,4.37,'Active'),
(42,'SUP042','EcoPack Manufacturing','Packaging','Menoufia',8,4.26,'Active'),
(43,'SUP043','SecureSeal Egypt','Packaging','Qalyubia',7,4.49,'Active'),
(44,'SUP044','PalletPro Egypt','Packaging','Alexandria',12,4.04,'Active'),
(45,'SUP045','ValuePack Industries','Packaging','Giza',9,3.82,'Inactive');

--2 Materials (categories fixed to match the CHECK list)
INSERT INTO Materials
(
    MaterialID, MaterialCode, MaterialName, MaterialCategory,
    UOM, StorageType, ShelfLifeDays, StandardCost, Status
)
VALUES
(1,'MAT001','Raw Cow Milk','Raw Milk','L','Chilled',2,28.0000,'Active'),
(2,'MAT002','Refined Sugar','Ingredient','KG','Ambient',730,38.0000,'Active'),
(3,'MAT003','Skim Milk Powder','Ingredient','KG','Ambient',365,170.0000,'Active'),
(4,'MAT004','Yoghurt Starter Culture','Culture','KG','Frozen',540,7500.0000,'Active'),
(5,'MAT005','Stabilizer Blend','Ingredient','KG','Ambient',365,220.0000,'Active'),
(6,'MAT006','Strawberry Fruit Preparation','Fruit Preparation','KG','Chilled',120,95.0000,'Active'),
(7,'MAT007','Mango Fruit Preparation','Fruit Preparation','KG','Chilled',120,88.0000,'Active'),
(8,'MAT008','Blueberry Fruit Preparation','Fruit Preparation','KG','Chilled',120,115.0000,'Active'),
(9,'MAT009','Vanilla Flavor Concentrate','Flavor','KG','Ambient',365,650.0000,'Active'),
(10,'MAT010','170g PP Cup','Packaging','PCS','Ambient',1095,1.2000,'Active'),
(11,'MAT011','400g PP Tub','Packaging','PCS','Ambient',1095,2.3000,'Active'),
(12,'MAT012','1kg PP Tub','Packaging','PCS','Ambient',1095,4.8000,'Active'),
(13,'MAT013','95mm Foil Lid','Packaging','PCS','Ambient',1095,0.3800,'Active'),
(14,'MAT014','120mm Foil Lid','Packaging','PCS','Ambient',1095,0.5500,'Active'),
(15,'MAT015','150mm Foil Lid','Packaging','PCS','Ambient',1095,0.8000,'Active'),
(16,'MAT016','Carton 12 x 170g','Packaging','PCS','Ambient',1095,7.5000,'Active'),
(17,'MAT017','Carton 6 x 400g','Packaging','PCS','Ambient',1095,6.8000,'Active'),
(18,'MAT018','Carton 6 x 1kg','Packaging','PCS','Ambient',1095,8.5000,'Active'),
(19,'MAT019','Shrink Film','Packaging','KG','Ambient',730,72.0000,'Active'),
(20,'MAT020','Food Grade Plastic Pallet','Packaging','PCS','Ambient',1825,380.0000,'Active');

--3 Products
INSERT INTO Products
(
    ProductID, ProductCode, ProductName, ProductFamily, Flavor,
    PackSizeG, UnitsPerCase, TargetPH, ShelfLifeDays, Status
)
VALUES
(1,'PRD001','Plain Set Yoghurt 170g','Set Yoghurt','Plain',170,12,4.45,21,'Active'),
(2,'PRD002','Strawberry Set Yoghurt 170g','Set Yoghurt','Strawberry',170,12,4.45,21,'Active'),
(3,'PRD003','Mango Set Yoghurt 170g','Set Yoghurt','Mango',170,12,4.45,21,'Active'),
(4,'PRD004','Vanilla Set Yoghurt 170g','Set Yoghurt','Vanilla',170,12,4.45,21,'Active'),
(5,'PRD005','Plain Stirred Yoghurt 400g','Stirred Yoghurt','Plain',400,6,4.40,21,'Active'),
(6,'PRD006','Strawberry Stirred Yoghurt 400g','Stirred Yoghurt','Strawberry',400,6,4.40,21,'Active'),
(7,'PRD007','Mango Stirred Yoghurt 400g','Stirred Yoghurt','Mango',400,6,4.40,21,'Active'),
(8,'PRD008','Blueberry Stirred Yoghurt 400g','Stirred Yoghurt','Blueberry',400,6,4.40,21,'Active'),
(9,'PRD009','Plain Family Yoghurt 1kg','Family Tub','Plain',1000,6,4.40,18,'Active'),
(10,'PRD010','Strawberry Family Yoghurt 1kg','Family Tub','Strawberry',1000,6,4.40,18,'Active'),
(11,'PRD011','Mango Family Yoghurt 1kg','Family Tub','Mango',1000,6,4.40,18,'Active'),
(12,'PRD012','Vanilla Family Yoghurt 1kg','Family Tub','Vanilla',1000,6,4.40,18,'Active');

--4 ProductionLines
INSERT INTO ProductionLines
(
    LineID, LineCode, LineName, RatedCapacityKgPerHour, Status
)
VALUES
(1,'YG01','Set Cup Line',5000.00,'Active'),
(2,'YG02','Stirred Tub Line',6000.00,'Active'),
(3,'YG03','Family Tub Line',7500.00,'Active'),
(4,'YG04','Flexible Backup Line',4500.00,'Active');

/* ========================================================
   Helper number table - up to 120,000 rows
   ======================================================== */
;WITH E1(N) AS
(
    SELECT 1
    FROM (VALUES(0),(0),(0),(0),(0),(0),(0),(0),(0),(0)) v(n)
),
E2(N) AS (SELECT 1 FROM E1 a CROSS JOIN E1 b),
E4(N) AS (SELECT 1 FROM E2 a CROSS JOIN E2 b),
E6(N) AS (SELECT 1 FROM E4 a CROSS JOIN E2 b)
SELECT TOP (120000)
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
INTO #Numbers
FROM E6;

CREATE UNIQUE CLUSTERED INDEX IX_Numbers_n ON #Numbers(n);

--5 PurchaseOrders (FreightCost added)
;WITH POBase AS
(
    SELECT
        n,
        CASE
            WHEN n <= 15000 THEN 1 + ((n - 1) % 18)
            WHEN n <= 22500 THEN 19 + ((n - 15001) % 12)
            ELSE 31 + ((n - 22501) % 15)
        END AS SupplierID,
        DATEADD
        (
            DAY,
            ((CHECKSUM(CONCAT('PO-DATE-', n)) & 2147483647) % 974),
            CAST('2024-01-01' AS date)
        ) AS PODate
    FROM #Numbers
    WHERE n <= 30000
)
INSERT INTO PurchaseOrders
(
    POID, PONumber, SupplierID, PODate, ExpectedDate,
    POStatus, Currency, FreightCost
)
SELECT
    b.n AS POID,
    CONCAT('PO-', RIGHT('000000' + CAST(b.n AS varchar(6)), 6)) AS PONumber,
    b.SupplierID,
    b.PODate,
    DATEADD(DAY, s.LeadTimeDays + (b.n % 3), b.PODate) AS ExpectedDate,
    CASE
        WHEN b.n % 100 < 3 THEN 'Cancelled'
        WHEN b.n % 100 < 12 THEN 'Partial'
        ELSE 'Closed'
    END AS POStatus,
    CASE
        WHEN s.SupplierType = 'Dairy Farm' THEN 'EGP'
        WHEN s.SupplierType = 'Ingredient' AND b.n % 10 = 0 THEN 'EUR'
        WHEN s.SupplierType = 'Ingredient' AND b.n % 10 = 1 THEN 'USD'
        ELSE 'EGP'
    END AS Currency,
    CAST
    (
        CASE s.SupplierType
            WHEN 'Dairy Farm' THEN 800 + ((CHECKSUM(CONCAT('FRT-', b.n)) & 2147483647) % 2201)
            WHEN 'Ingredient' THEN 250 + ((CHECKSUM(CONCAT('FRT-', b.n)) & 2147483647) % 1751)
            ELSE 150 + ((CHECKSUM(CONCAT('FRT-', b.n)) & 2147483647) % 1351)
        END AS decimal(12,2)
    ) AS FreightCost
FROM POBase b
JOIN Suppliers s
    ON s.SupplierID = b.SupplierID;

--6 PurchaseOrderLines
;WITH LineSource AS
(
    SELECT
        po.POID,
        po.SupplierID,
        po.POStatus,
        s.SupplierType,
        L.LnNo,
        CASE
            WHEN s.SupplierType = 'Dairy Farm' THEN 1
            WHEN s.SupplierType = 'Ingredient' THEN 2 + ((po.POID + L.LnNo - 2) % 8)
            ELSE 10 + ((po.POID + L.LnNo - 2) % 11)
        END AS MaterialID
    FROM PurchaseOrders po
    JOIN Suppliers s
        ON s.SupplierID = po.SupplierID
    CROSS APPLY (VALUES(1),(2),(3),(4),(5),(6)) L(LnNo)
    WHERE s.SupplierType <> 'Dairy Farm'
       OR L.LnNo = 1
),
QtyBase AS
(
    SELECT
        ls.*,
        m.StandardCost,
        CAST
        (
            CASE
                WHEN ls.MaterialID = 1 THEN 6000 + ((CHECKSUM(CONCAT('QTY-MILK-', ls.POID)) & 2147483647) % 24001)
                WHEN ls.MaterialID = 2 THEN 800 + ((CHECKSUM(CONCAT('QTY-SUGAR-', ls.POID, '-', ls.LnNo)) & 2147483647) % 4201)
                WHEN ls.MaterialID = 3 THEN 250 + ((CHECKSUM(CONCAT('QTY-SMP-', ls.POID, '-', ls.LnNo)) & 2147483647) % 1501)
                WHEN ls.MaterialID = 4 THEN 5 + ((CHECKSUM(CONCAT('QTY-CULT-', ls.POID, '-', ls.LnNo)) & 2147483647) % 26)
                WHEN ls.MaterialID = 5 THEN 100 + ((CHECKSUM(CONCAT('QTY-STAB-', ls.POID, '-', ls.LnNo)) & 2147483647) % 501)
                WHEN ls.MaterialID BETWEEN 6 AND 9 THEN 300 + ((CHECKSUM(CONCAT('QTY-FRUIT-', ls.POID, '-', ls.LnNo)) & 2147483647) % 2401)
                WHEN ls.MaterialID BETWEEN 10 AND 15 THEN 50000 + ((CHECKSUM(CONCAT('QTY-PACK-', ls.POID, '-', ls.LnNo)) & 2147483647) % 450001)
                WHEN ls.MaterialID BETWEEN 16 AND 18 THEN 5000 + ((CHECKSUM(CONCAT('QTY-CARTON-', ls.POID, '-', ls.LnNo)) & 2147483647) % 45001)
                WHEN ls.MaterialID = 19 THEN 500 + ((CHECKSUM(CONCAT('QTY-FILM-', ls.POID, '-', ls.LnNo)) & 2147483647) % 2501)
                ELSE 50 + ((CHECKSUM(CONCAT('QTY-PALLET-', ls.POID, '-', ls.LnNo)) & 2147483647) % 451)
            END AS decimal(14,3)
        ) AS OrderedQty
    FROM LineSource ls
    JOIN Materials m
        ON m.MaterialID = ls.MaterialID
)
INSERT INTO PurchaseOrderLines
(
    POLineID, POID, MaterialID, OrderedQty,
    ReceivedQty, UnitCost, LineStatus
)
SELECT
    ROW_NUMBER() OVER (ORDER BY q.POID, q.LnNo) AS POLineID,
    q.POID,
    q.MaterialID,
    q.OrderedQty,
    CAST
    (
        CASE
            WHEN q.POStatus = 'Cancelled' THEN 0
            WHEN q.POStatus = 'Partial' AND q.LnNo % 3 = 0
                THEN q.OrderedQty * (0.55 + ((q.POID + q.LnNo) % 31) / 100.0)
            WHEN q.POStatus = 'Partial'
                THEN q.OrderedQty * (0.98 + ((q.POID + q.LnNo) % 3) / 100.0)
            ELSE q.OrderedQty * (0.97 + ((q.POID + q.LnNo) % 4) / 100.0)
        END AS decimal(14,3)
    ) AS ReceivedQty,
    CAST
    (
        q.StandardCost *
        (0.94 + ((CHECKSUM(CONCAT('COST-', q.POID, '-', q.LnNo)) & 2147483647) % 15) / 100.0)
        AS decimal(12,4)
    ) AS UnitCost,
    CASE
        WHEN q.POStatus = 'Cancelled' THEN 'Cancelled'
        WHEN q.POStatus = 'Partial' AND q.LnNo % 3 = 0 THEN 'Partial'
        ELSE 'Received'
    END AS LineStatus
FROM QtyBase q;

--7 ProductionBatches
;WITH BatchBase AS
(
    SELECT
        n AS BatchID,
        1 + ((CHECKSUM(CONCAT('PRODUCT-', n)) & 2147483647) % 12) AS ProductID,
        DATEADD
        (
            DAY,
            ((CHECKSUM(CONCAT('BATCH-DATE-', n)) & 2147483647) % 974),
            CAST('2024-01-01' AS date)
        ) AS ProductionDate,
        CAST(3000 + ((CHECKSUM(CONCAT('PLAN-KG-', n)) & 2147483647) % 12001) AS decimal(14,2)) AS PlannedQtyKg
    FROM #Numbers
    WHERE n <= 12000
),
BatchCalc AS
(
    SELECT
        b.*,
        p.PackSizeG,
        CASE
            WHEN b.BatchID % 10 = 0 THEN 4
            WHEN p.PackSizeG = 170 THEN 1
            WHEN p.PackSizeG = 400 THEN 2
            ELSE 3
        END AS LineID,
        DATEADD(HOUR, (b.BatchID % 4) * 6, CAST(b.ProductionDate AS datetime2)) AS StartDateTime
    FROM BatchBase b
    JOIN Products p
        ON p.ProductID = b.ProductID
)
INSERT INTO ProductionBatches
(
    BatchID, BatchCode, ProductID, LineID, ProductionDate,
    PlannedQtyKg, ActualQtyKg, RejectQtyKg,
    StartDateTime, EndDateTime, BatchStatus
)
SELECT
    b.BatchID,
    CONCAT('B-', RIGHT('000000' + CAST(b.BatchID AS varchar(6)), 6)) AS BatchCode,
    b.ProductID,
    b.LineID,
    b.ProductionDate,
    b.PlannedQtyKg,
    CAST
    (
        b.PlannedQtyKg *
        (0.955 + ((CHECKSUM(CONCAT('ACTUAL-', b.BatchID)) & 2147483647) % 51) / 1000.0)
        AS decimal(14,2)
    ) AS ActualQtyKg,
    CAST
    (
        b.PlannedQtyKg *
        (0.002 + ((CHECKSUM(CONCAT('REJECT-', b.BatchID)) & 2147483647) % 26) / 1000.0)
        AS decimal(14,2)
    ) AS RejectQtyKg,
    b.StartDateTime,
    DATEADD(HOUR, 4 + (b.BatchID % 4), b.StartDateTime) AS EndDateTime,
    CASE
        WHEN b.BatchID % 100 < 2 THEN 'Rejected'
        WHEN b.BatchID % 100 < 6 THEN 'On Hold'
        ELSE 'Released'
    END AS BatchStatus
FROM BatchCalc b;

--8 BatchMaterialUsage
;WITH UsageSlots AS
(
    SELECT
        pb.BatchID,
        pb.ProductID,
        pb.ProductionDate,
        pb.PlannedQtyKg,
        p.Flavor,
        p.PackSizeG,
        p.UnitsPerCase,
        S.SlotNo,
        CASE S.SlotNo
            WHEN 1 THEN 1
            WHEN 2 THEN 2
            WHEN 3 THEN 3
            WHEN 4 THEN 4
            WHEN 5 THEN 5
            WHEN 6 THEN CASE p.Flavor
                            WHEN 'Strawberry' THEN 6
                            WHEN 'Mango' THEN 7
                            WHEN 'Blueberry' THEN 8
                            WHEN 'Vanilla' THEN 9
                         END
            WHEN 7 THEN CASE p.PackSizeG WHEN 170 THEN 10 WHEN 400 THEN 11 ELSE 12 END
            WHEN 8 THEN CASE p.PackSizeG WHEN 170 THEN 13 WHEN 400 THEN 14 ELSE 15 END
            WHEN 9 THEN CASE p.PackSizeG WHEN 170 THEN 16 WHEN 400 THEN 17 ELSE 18 END
            WHEN 10 THEN 19
        END AS MaterialID
    FROM ProductionBatches pb
    JOIN Products p
        ON p.ProductID = pb.ProductID
    CROSS APPLY (VALUES(1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) S(SlotNo)
    WHERE NOT (S.SlotNo = 6 AND p.Flavor = 'Plain')
),
UsagePlanned AS
(
    SELECT
        u.*,
        m.MaterialCode,
        m.StandardCost,
        CAST
        (
            CASE u.SlotNo
                WHEN 1 THEN u.PlannedQtyKg * 0.93
                WHEN 2 THEN u.PlannedQtyKg * 0.055
                WHEN 3 THEN u.PlannedQtyKg * 0.025
                WHEN 4 THEN u.PlannedQtyKg * 0.00025
                WHEN 5 THEN u.PlannedQtyKg * 0.004
                WHEN 6 THEN CASE WHEN u.Flavor = 'Vanilla' THEN u.PlannedQtyKg * 0.0015
                                 ELSE u.PlannedQtyKg * 0.10 END
                WHEN 7 THEN (u.PlannedQtyKg * 1000.0) / u.PackSizeG
                WHEN 8 THEN (u.PlannedQtyKg * 1000.0) / u.PackSizeG
                WHEN 9 THEN ((u.PlannedQtyKg * 1000.0) / u.PackSizeG) / u.UnitsPerCase
                WHEN 10 THEN u.PlannedQtyKg * 0.0015
            END AS decimal(14,3)
        ) AS PlannedQty
    FROM UsageSlots u
    JOIN Materials m
        ON m.MaterialID = u.MaterialID
)
INSERT INTO BatchMaterialUsage
(
    UsageID, BatchID, MaterialID, MaterialLotNo,
    PlannedQty, ActualQty, WasteQty, UnitCost
)
SELECT
    ROW_NUMBER() OVER (ORDER BY u.BatchID, u.SlotNo) AS UsageID,
    u.BatchID,
    u.MaterialID,
    CONCAT
    (
        'LOT-',
        RIGHT('000' + CAST(u.MaterialID AS varchar(3)), 3), '-',
        CONVERT(char(6), u.ProductionDate, 12), '-',
        RIGHT('0000' + CAST(u.BatchID % 10000 AS varchar(4)), 4)
    ) AS MaterialLotNo,
    u.PlannedQty,
    CAST
    (
        u.PlannedQty *
        (0.985 + ((CHECKSUM(CONCAT('USE-', u.BatchID, '-', u.SlotNo)) & 2147483647) % 41) / 1000.0)
        AS decimal(14,3)
    ) AS ActualQty,
    CAST
    (
        u.PlannedQty *
        (0.001 + ((CHECKSUM(CONCAT('WASTE-', u.BatchID, '-', u.SlotNo)) & 2147483647) % 15) / 1000.0)
        AS decimal(14,3)
    ) AS WasteQty,
    CAST
    (
        u.StandardCost *
        (0.97 + ((CHECKSUM(CONCAT('UCOST-', u.BatchID, '-', u.SlotNo)) & 2147483647) % 9) / 100.0)
        AS decimal(12,4)
    ) AS UnitCost
FROM UsagePlanned u;

--9 QualityInspections
;WITH InspectionBase AS
(
    SELECT
        n AS InspectionID,
        CASE
            WHEN n <= 30000 THEN 'IncomingMilk'
            WHEN n <= 65000 THEN 'InProcess'
            ELSE 'FinishedProduct'
        END AS InspectionType,
        CASE
            WHEN n <= 30000 THEN 1 + ((CHECKSUM(CONCAT('QC-SUP-', n)) & 2147483647) % 18)
            ELSE NULL
        END AS SupplierID,
        CASE
            WHEN n <= 30000 THEN NULL
            ELSE 1 + ((CHECKSUM(CONCAT('QC-BATCH-', n)) & 2147483647) % 12000)
        END AS BatchID
    FROM #Numbers
    WHERE n <= 100000
),
InspectionValues AS
(
    SELECT
        i.*,
        CASE
            WHEN i.InspectionType = 'IncomingMilk'
                THEN DATEADD
                     (
                        MINUTE,
                        ((CHECKSUM(CONCAT('QC-TIME-', i.InspectionID)) & 2147483647) % 1440),
                        CAST(DATEADD(DAY, ((CHECKSUM(CONCAT('QC-DATE-', i.InspectionID)) & 2147483647) % 974), CAST('2024-01-01' AS date)) AS datetime2)
                     )
            ELSE DATEADD
                 (
                    MINUTE,
                    CASE WHEN i.InspectionType = 'InProcess' THEN 120 ELSE 360 END
                    + ((CHECKSUM(CONCAT('QC-OFFSET-', i.InspectionID)) & 2147483647) % 90),
                    pb.StartDateTime
                 )
        END AS InspectionDateTime,
        CAST
        (
            CASE
                WHEN i.InspectionType = 'IncomingMilk' AND i.InspectionID % 40 = 0
                    THEN 8.2 + (i.InspectionID % 18) / 10.0
                WHEN i.InspectionType = 'IncomingMilk'
                    THEN 2.5 + ((CHECKSUM(CONCAT('TEMP-IN-', i.InspectionID)) & 2147483647) % 41) / 10.0
                WHEN i.InspectionType = 'InProcess'
                    THEN 40.0 + ((CHECKSUM(CONCAT('TEMP-IP-', i.InspectionID)) & 2147483647) % 51) / 10.0
                WHEN i.InspectionID % 50 = 0
                    THEN 8.0 + (i.InspectionID % 16) / 10.0
                ELSE 3.5 + ((CHECKSUM(CONCAT('TEMP-FP-', i.InspectionID)) & 2147483647) % 36) / 10.0
            END AS decimal(4,1)
        ) AS TemperatureC,
        CAST
        (
            CASE
                WHEN i.InspectionType = 'IncomingMilk' AND i.InspectionID % 55 = 0
                    THEN 6.48 + (i.InspectionID % 5) / 100.0
                WHEN i.InspectionType = 'IncomingMilk'
                    THEN 6.60 + ((CHECKSUM(CONCAT('PH-IN-', i.InspectionID)) & 2147483647) % 21) / 100.0
                WHEN i.InspectionType = 'InProcess'
                    THEN 4.20 + ((CHECKSUM(CONCAT('PH-IP-', i.InspectionID)) & 2147483647) % 51) / 100.0
                ELSE 4.20 + ((CHECKSUM(CONCAT('PH-FP-', i.InspectionID)) & 2147483647) % 36) / 100.0
            END AS decimal(3,2)
        ) AS PHValue,
        CAST
        (
            CASE
                WHEN i.InspectionType = 'IncomingMilk'
                    THEN 3.20 + ((CHECKSUM(CONCAT('FAT-IN-', i.InspectionID)) & 2147483647) % 111) / 100.0
                ELSE 2.60 + ((CHECKSUM(CONCAT('FAT-OUT-', i.InspectionID)) & 2147483647) % 81) / 100.0
            END AS decimal(4,2)
        ) AS FatPct,
        CASE
            WHEN i.InspectionType = 'IncomingMilk' AND i.InspectionID % 25 = 0
                THEN 120000 + ((CHECKSUM(CONCAT('BAC-HIGH-', i.InspectionID)) & 2147483647) % 70001)
            WHEN i.InspectionType = 'IncomingMilk'
                THEN 20000 + ((CHECKSUM(CONCAT('BAC-IN-', i.InspectionID)) & 2147483647) % 76001)
            ELSE 100 + ((CHECKSUM(CONCAT('BAC-OUT-', i.InspectionID)) & 2147483647) % 4901)
        END AS BacteriaCountCFU
    FROM InspectionBase i
    LEFT JOIN ProductionBatches pb
        ON pb.BatchID = i.BatchID
),
InspectionResult AS
(
    SELECT
        v.*,
        CASE
            WHEN v.InspectionType = 'IncomingMilk'
                 AND (v.TemperatureC > 8.0 OR v.PHValue < 6.55 OR v.PHValue > 6.85 OR v.BacteriaCountCFU > 100000)
                THEN 'Fail'
            WHEN v.InspectionType = 'IncomingMilk'
                 AND (v.TemperatureC > 6.0 OR v.BacteriaCountCFU >= 80000)
                THEN 'Hold'
            WHEN v.InspectionType = 'IncomingMilk'
                THEN 'Pass'
            WHEN v.InspectionType = 'InProcess'
                 AND (v.TemperatureC < 39.0 OR v.TemperatureC > 46.0 OR v.PHValue < 4.15 OR v.PHValue > 4.70)
                THEN 'Fail'
            WHEN v.InspectionType = 'InProcess' AND v.PHValue > 4.60
                THEN 'Hold'
            WHEN v.InspectionType = 'InProcess'
                THEN 'Pass'
            WHEN v.InspectionType = 'FinishedProduct'
                 AND (v.TemperatureC > 8.0 OR v.PHValue < 4.15 OR v.PHValue > 4.55)
                THEN 'Fail'
            WHEN v.InspectionType = 'FinishedProduct'
                 AND (v.TemperatureC > 7.0 OR v.PHValue > 4.50)
                THEN 'Hold'
            ELSE 'Pass'
        END AS Result
    FROM InspectionValues v
)
INSERT INTO QualityInspections
(
    InspectionID, InspectionType, SupplierID, BatchID,
    InspectionDateTime, TemperatureC, PHValue, FatPct,
    BacteriaCountCFU, Result, InspectorCode, Notes
)
SELECT
    r.InspectionID,
    r.InspectionType,
    r.SupplierID,
    r.BatchID,
    r.InspectionDateTime,
    r.TemperatureC,
    r.PHValue,
    r.FatPct,
    r.BacteriaCountCFU,
    r.Result,
    CONCAT('QC', RIGHT('000' + CAST(1 + (r.InspectionID % 25) AS varchar(3)), 3)) AS InspectorCode,
    CASE r.Result
        WHEN 'Fail' THEN 'Result outside release limits - investigation required'
        WHEN 'Hold' THEN 'Borderline result - pending quality review'
        ELSE NULL
    END AS Notes
FROM InspectionResult r;

--10 Dispatches
;WITH DispatchBase AS
(
    SELECT
        n AS DispatchID,
        1 + ((CHECKSUM(CONCAT('DSP-BATCH-', n)) & 2147483647) % 12000) AS BatchID
    FROM #Numbers
    WHERE n <= 100000
),
DispatchValues AS
(
    SELECT
        d.DispatchID,
        d.BatchID,
        DATEADD
        (
            HOUR,
            6 + (d.DispatchID % 10),
            DATEADD(DAY, 1 + (d.DispatchID % 5), pb.EndDateTime)
        ) AS DispatchDateTime,
        CASE d.DispatchID % 12
            WHEN 0 THEN 'Cairo'
            WHEN 1 THEN 'Giza'
            WHEN 2 THEN 'Alexandria'
            WHEN 3 THEN 'Sharqia'
            WHEN 4 THEN 'Dakahlia'
            WHEN 5 THEN 'Gharbia'
            WHEN 6 THEN 'Beheira'
            WHEN 7 THEN 'Ismailia'
            WHEN 8 THEN 'Suez'
            WHEN 9 THEN 'Minya'
            WHEN 10 THEN 'Assiut'
            ELSE 'Sohag'
        END AS DestinationGovernorate,
        CASE d.DispatchID % 10
            WHEN 0 THEN 'Delta Fresh Distribution'
            WHEN 1 THEN 'Cairo Cold Chain Co.'
            WHEN 2 THEN 'Nile Food Logistics'
            WHEN 3 THEN 'Mediterranean Distribution'
            WHEN 4 THEN 'Upper Egypt Food Service'
            WHEN 5 THEN 'Canal Markets Supply'
            WHEN 6 THEN 'FreshRoute Egypt'
            WHEN 7 THEN 'Prime Grocery Distribution'
            WHEN 8 THEN 'CityMart Supply Network'
            ELSE 'Family Foods Distribution'
        END AS DistributorName,
        20 + ((CHECKSUM(CONCAT('CASE-QTY-', d.DispatchID)) & 2147483647) % 381) AS QuantityCases,
        CONCAT('RF-', RIGHT('000' + CAST(1 + (d.DispatchID % 80) AS varchar(3)), 3)) AS TruckCode,
        CAST
        (
            CASE
                WHEN d.DispatchID % 50 = 0
                    THEN 8.1 + (d.DispatchID % 19) / 10.0
                ELSE 3.0 + ((CHECKSUM(CONCAT('DSP-TEMP-', d.DispatchID)) & 2147483647) % 36) / 10.0
            END AS decimal(4,1)
        ) AS DispatchTemperatureC
    FROM DispatchBase d
    JOIN ProductionBatches pb
        ON pb.BatchID = d.BatchID
)
INSERT INTO Dispatches
(
    DispatchID, DispatchNumber, BatchID, DispatchDateTime,
    DestinationGovernorate, DistributorName, QuantityCases,
    TruckCode, DispatchTemperatureC, DeliveryStatus
)
SELECT
    d.DispatchID,
    CONCAT('DSP-', RIGHT('000000' + CAST(d.DispatchID AS varchar(6)), 6)) AS DispatchNumber,
    d.BatchID,
    d.DispatchDateTime,
    d.DestinationGovernorate,
    d.DistributorName,
    d.QuantityCases,
    d.TruckCode,
    d.DispatchTemperatureC,
    CASE
        WHEN d.DispatchTemperatureC > 8.0 AND d.DispatchID % 2 = 0 THEN 'Returned'
        WHEN d.DispatchTemperatureC > 8.0 THEN 'RejectedAtDestination'
        WHEN d.DispatchID % 100 < 3 THEN 'Returned'
        ELSE 'Delivered'
    END AS DeliveryStatus
FROM DispatchValues d;

DROP TABLE #Numbers;

COMMIT TRANSACTION;
GO

/* ============================================================
   3. VERIFICATION
   Expected: 45, 20, 12, 4, 30000, 105000, 12000, ~117000, 100000, 100000
   ============================================================ */
SELECT 'Suppliers' AS TableName, COUNT(*) AS TotalRows FROM Suppliers
UNION ALL SELECT 'Materials', COUNT(*) FROM Materials
UNION ALL SELECT 'Products', COUNT(*) FROM Products
UNION ALL SELECT 'ProductionLines', COUNT(*) FROM ProductionLines
UNION ALL SELECT 'PurchaseOrders', COUNT(*) FROM PurchaseOrders
UNION ALL SELECT 'PurchaseOrderLines', COUNT(*) FROM PurchaseOrderLines
UNION ALL SELECT 'ProductionBatches', COUNT(*) FROM ProductionBatches
UNION ALL SELECT 'BatchMaterialUsage', COUNT(*) FROM BatchMaterialUsage
UNION ALL SELECT 'Inspections', COUNT(*) FROM QualityInspections
UNION ALL SELECT 'Dispatches', COUNT(*) FROM Dispatches;
GO

/* ============================================================
   4. QUESTIONS
   ============================================================ */

-- 1
SELECT SupplierCode, SupplierName, Governorate, LeadTimeDays, QualityRating
FROM Suppliers
WHERE Governorate IN ('Beheira','Dakahlia','Sharqia') AND QualityRating >= 4.30
ORDER BY QualityRating DESC;

-- 2
SELECT MaterialCode, MaterialName, MaterialCategory, StorageType, ShelfLifeDays, StandardCost
FROM Materials
WHERE StorageType IN ('Chilled','Frozen') AND ShelfLifeDays <= 180
ORDER BY ShelfLifeDays ASC;

-- 3
SELECT ProductCode, ProductName, ProductFamily, Flavor, PackSizeG, UnitsPerCase, ShelfLifeDays
FROM Products
WHERE PackSizeG IN (170, 400)
ORDER BY PackSizeG, ProductName;

-- 4
SELECT po.PONumber, po.PODate, po.ExpectedDate, s.SupplierName, s.SupplierType, po.POStatus, po.Currency, po.FreightCost
FROM Suppliers s
JOIN PurchaseOrders po ON s.SupplierID = po.SupplierID
WHERE po.PODate >= '2026-04-01' AND po.PODate < '2026-07-01'
ORDER BY po.PODate DESC;

-- 5
SELECT TOP 20 pol.POLineID, po.PONumber, m.MaterialName, pol.OrderedQty, pol.UnitCost,
       pol.OrderedQty * pol.UnitCost AS LineValue
FROM PurchaseOrders po
JOIN PurchaseOrderLines pol ON po.POID = pol.POID
JOIN Materials m ON m.MaterialID = pol.MaterialID
ORDER BY LineValue DESC;

-- 6
SELECT pb.BatchCode, p.ProductName, pl.LineCode, pb.PlannedQtyKg, pb.ActualQtyKg, pb.RejectQtyKg,
       pb.ActualQtyKg * 100.0 / pb.PlannedQtyKg AS YieldPct,
       pb.RejectQtyKg * 100.0 / pb.ActualQtyKg AS RejectRatePct
FROM Products p
JOIN ProductionBatches pb ON p.ProductID = pb.ProductID
JOIN ProductionLines pl ON pl.LineID = pb.LineID
ORDER BY YieldPct DESC;

-- 7
SELECT d.DispatchNumber, d.DispatchDateTime, p.ProductName, d.DestinationGovernorate, d.QuantityCases, d.TruckCode, d.DispatchTemperatureC
FROM Products p
JOIN ProductionBatches pb ON p.ProductID = pb.ProductID
JOIN Dispatches d ON pb.BatchID = d.BatchID
WHERE d.DestinationGovernorate IN ('Cairo','Giza','Alexandria')
  AND MONTH(d.DispatchDateTime) IN (7, 8)
ORDER BY d.DispatchDateTime;

-- 8
-- Count distinct POs (the old query counted PO lines)
SELECT s.SupplierID, s.SupplierName,
       COUNT(DISTINCT po.POID) AS NumOfPOs,
       SUM(pol.OrderedQty * pol.UnitCost) AS TotalValue,
       AVG(po.FreightCost) AS AvgFreightCost
FROM PurchaseOrders po
JOIN Suppliers s ON s.SupplierID = po.SupplierID
JOIN PurchaseOrderLines pol ON po.POID = pol.POID
WHERE po.PODate >= '2026-01-01' AND po.PODate < '2027-01-01'
GROUP BY s.SupplierID, s.SupplierName
HAVING COUNT(DISTINCT po.POID) >= 10
ORDER BY TotalValue DESC;

-- 9
SELECT m.MaterialID, m.MaterialName, pol.LineStatus,
       COUNT(pol.POLineID) AS Lines,
       SUM(pol.OrderedQty) AS TotalOrderedQty,
       SUM(pol.ReceivedQty) AS TotalReceivedQty
FROM Materials m
JOIN PurchaseOrderLines pol ON m.MaterialID = pol.MaterialID
WHERE pol.LineStatus <> 'Cancelled'
GROUP BY m.MaterialID, m.MaterialName, pol.LineStatus
HAVING SUM(pol.ReceivedQty) * 100.0 / SUM(pol.OrderedQty) < 95 AND COUNT(pol.POLineID) >= 20;

-- 10
SELECT YEAR(ProductionDate) AS [Year],
       DATEPART(QUARTER, ProductionDate) AS [Quarter],
       COUNT(BatchID) AS TotalBatches,
       SUM(ActualQtyKg) AS TotalActual,
       SUM(PlannedQtyKg) AS TotalPlanned,
       SUM(RejectQtyKg) AS TotalReject,
       SUM(ActualQtyKg) * 100.0 / SUM(PlannedQtyKg) AS YieldPct
FROM ProductionBatches
WHERE YEAR(ProductionDate) = 2026 AND DATEPART(QUARTER, ProductionDate) = 2
GROUP BY YEAR(ProductionDate), DATEPART(QUARTER, ProductionDate);

-- 11
-- Suppliers that have both Fail and Hold inspections, with their fail rate
SELECT SupplierID,
       COUNT(*) AS TotalInspections,
       SUM(CASE WHEN Result = 'Fail' THEN 1 ELSE 0 END) AS TotalFail,
       SUM(CASE WHEN Result = 'Hold' THEN 1 ELSE 0 END) AS TotalHold,
       SUM(CASE WHEN Result = 'Fail' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS FailRatePct,
       AVG(TemperatureC) AS AvgTemp,
       AVG(BacteriaCountCFU) AS AvgBC
FROM QualityInspections
WHERE InspectionType = 'IncomingMilk'
GROUP BY SupplierID
HAVING SUM(CASE WHEN Result = 'Fail' THEN 1 ELSE 0 END) > 0
   AND SUM(CASE WHEN Result = 'Hold' THEN 1 ELSE 0 END) > 0
ORDER BY FailRatePct DESC;

-- 12
SELECT ProductID, AVG(RejectQtyKg * 100.0 / ActualQtyKg) AS AvgRejectRatePct
FROM ProductionBatches
GROUP BY ProductID
HAVING AVG(RejectQtyKg * 100.0 / ActualQtyKg) <
      (SELECT AVG(Overall)
       FROM (SELECT ProductID, AVG(RejectQtyKg * 100.0 / ActualQtyKg) AS Overall
             FROM ProductionBatches
             GROUP BY ProductID) AS T);

-- 13
SELECT m.MaterialID, m.MaterialName, YEAR(po.PODate) AS [Year],
       SUM(pol.OrderedQty * pol.UnitCost) AS PurchaseOrderValue
FROM PurchaseOrders po
JOIN PurchaseOrderLines pol ON po.POID = pol.POID
JOIN Materials m ON m.MaterialID = pol.MaterialID
WHERE YEAR(po.PODate) = 2026
GROUP BY m.MaterialID, m.MaterialName, YEAR(po.PODate)
HAVING SUM(pol.OrderedQty * pol.UnitCost) >
      (SELECT AVG(Total)
       FROM (SELECT POID, SUM(UnitCost * OrderedQty) AS Total
             FROM PurchaseOrderLines
             GROUP BY POID) AS T);

-- 14
WITH Summary AS
(
    SELECT DATEFROMPARTS(YEAR(ProductionDate), MONTH(ProductionDate), 1) AS MonthStart,
           COUNT(BatchID) AS BatchCount,
           SUM(PlannedQtyKg) AS TotalPlanned,
           SUM(ActualQtyKg) AS TotalActual,
           SUM(RejectQtyKg) AS TotalReject
    FROM ProductionBatches
    WHERE YEAR(ProductionDate) = 2026
    GROUP BY DATEFROMPARTS(YEAR(ProductionDate), MONTH(ProductionDate), 1)
)
SELECT MonthStart, BatchCount, TotalActual, TotalPlanned, TotalReject
FROM Summary
WHERE TotalActual > (SELECT AVG(TotalActual) FROM Summary)
ORDER BY MonthStart;

-- 15
WITH ProcurementSummary2026 AS
(
    SELECT s.SupplierID, s.SupplierName,
           SUM(pol.ReceivedQty * pol.UnitCost) AS ProcurementValue
    FROM Suppliers s
    JOIN PurchaseOrders po ON s.SupplierID = po.SupplierID
    JOIN PurchaseOrderLines pol ON po.POID = pol.POID
    JOIN Materials m ON pol.MaterialID = m.MaterialID
    WHERE s.SupplierType = 'Dairy Farm'
      AND m.MaterialCategory = 'Raw Milk'
      AND YEAR(po.PODate) = 2026
    GROUP BY s.SupplierID, s.SupplierName
),
QualitySummary AS
(
    SELECT SupplierID,
           SUM(CASE WHEN Result = 'Pass' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS PassRatePct
    FROM QualityInspections
    WHERE InspectionType = 'IncomingMilk'
    GROUP BY SupplierID
)
SELECT ps.SupplierID, ps.SupplierName, ps.ProcurementValue, qs.PassRatePct
FROM ProcurementSummary2026 ps
JOIN QualitySummary qs ON ps.SupplierID = qs.SupplierID
WHERE ps.ProcurementValue > (SELECT AVG(ProcurementValue) FROM ProcurementSummary2026)
  AND qs.PassRatePct >= 90;

-- 16
SELECT *
FROM
(
    SELECT s.SupplierType, s.SupplierName,
           SUM(pol.ReceivedQty * pol.UnitCost) AS TotalProcurementValue,
           DENSE_RANK() OVER (PARTITION BY s.SupplierType ORDER BY SUM(pol.ReceivedQty * pol.UnitCost) DESC) AS DR
    FROM Suppliers s
    JOIN PurchaseOrders po ON s.SupplierID = po.SupplierID
    JOIN PurchaseOrderLines pol ON po.POID = pol.POID
    WHERE YEAR(po.PODate) = 2026
    GROUP BY s.SupplierType, s.SupplierName
) AS Ranking
WHERE DR <= 3
ORDER BY SupplierType, DR;

-- 17
WITH RankedPOs AS
(
    SELECT s.SupplierID, s.SupplierName, po.PONumber, po.PODate, po.POID, po.POStatus, po.FreightCost,
           ROW_NUMBER() OVER (PARTITION BY s.SupplierID ORDER BY po.PODate DESC, po.POID DESC) AS RN
    FROM PurchaseOrders po
    JOIN Suppliers s ON po.SupplierID = s.SupplierID
)
SELECT *
FROM RankedPOs
WHERE RN <= 3;

-- 18
-- Yield per day = total actual / total planned (the old query added up percentages)
WITH Yield AS
(
    SELECT ProductID, ProductionDate,
           SUM(ActualQtyKg) * 100.0 / SUM(PlannedQtyKg) AS YieldPct
    FROM ProductionBatches
    WHERE YEAR(ProductionDate) = 2026
    GROUP BY ProductID, ProductionDate
),
Ranked AS
(
    SELECT ProductID, ProductionDate, YieldPct,
           DENSE_RANK() OVER (PARTITION BY ProductID ORDER BY YieldPct DESC) AS DNR
    FROM Yield
)
SELECT *
FROM Ranked
WHERE DNR <= 5;

-- 19
-- Running total per product (partitioning by date too made it restart every day)
SELECT p.ProductName, pb.BatchCode, pb.ProductionDate, pb.ActualQtyKg,
       SUM(pb.ActualQtyKg) OVER (PARTITION BY p.ProductID ORDER BY pb.ProductionDate, pb.BatchID) AS TotalActualKg
FROM ProductionBatches pb
JOIN Products p ON pb.ProductID = p.ProductID
WHERE YEAR(pb.ProductionDate) = 2026;

-- 20
-- Variance uses material quantities (not batch output kg)
WITH MaterialCost AS
(
    SELECT pb.BatchID, pb.ProductID,
           SUM((bm.ActualQty - bm.PlannedQty) * bm.UnitCost) AS MaterialVarianceCost
    FROM ProductionBatches pb
    JOIN BatchMaterialUsage bm ON pb.BatchID = bm.BatchID
    GROUP BY pb.BatchID, pb.ProductID
),
Average AS
(
    SELECT BatchID, ProductID, MaterialVarianceCost,
           AVG(MaterialVarianceCost) OVER (PARTITION BY ProductID) AS AvgMaterialCost
    FROM MaterialCost
)
SELECT *,
       DENSE_RANK() OVER (PARTITION BY ProductID ORDER BY MaterialVarianceCost DESC) AS [Rank]
FROM Average
WHERE MaterialVarianceCost > AvgMaterialCost;

-- 21
WITH MonthlyResults AS
(
    SELECT InspectionType,
           MONTH(InspectionDateTime) AS Months,
           COUNT(*) AS TotalChecks,
           SUM(CASE WHEN Result = 'Fail' THEN 1 ELSE 0 END) AS FailedChecks
    FROM QualityInspections
    WHERE YEAR(InspectionDateTime) = 2026
    GROUP BY InspectionType, MONTH(InspectionDateTime)
)
SELECT InspectionType, Months, TotalChecks, FailedChecks,
       SUM(FailedChecks) OVER (PARTITION BY InspectionType ORDER BY Months) AS CumulativeFailures
FROM MonthlyResults
ORDER BY InspectionType, Months;

-- 22
WITH LineMonthly AS
(
    SELECT pl.LineCode, pl.LineName,
           MONTH(pb.ProductionDate) AS Months,
           COUNT(*) AS BatchCount,
           SUM(pb.ActualQtyKg) AS TotalActualKg,
           SUM(pb.RejectQtyKg) AS TotalRejectKg,
           AVG(pb.ActualQtyKg * 100.0 / pb.PlannedQtyKg) AS AverageYieldPct,
           DENSE_RANK() OVER (PARTITION BY MONTH(pb.ProductionDate) ORDER BY SUM(pb.ActualQtyKg) DESC) AS LineRank
    FROM ProductionBatches pb
    JOIN ProductionLines pl ON pl.LineID = pb.LineID
    WHERE YEAR(pb.ProductionDate) = 2026
    GROUP BY pl.LineCode, pl.LineName, MONTH(pb.ProductionDate)
)
SELECT Months, LineRank, LineCode, LineName, BatchCount, TotalActualKg, TotalRejectKg, AverageYieldPct
FROM LineMonthly
WHERE LineRank <= 2
ORDER BY Months, LineRank, LineCode;

-- 23
WITH DistributorMix AS
(
    SELECT d.DistributorName, p.ProductFamily,
           SUM(d.QuantityCases) AS TotalCases,
           SUM(SUM(d.QuantityCases)) OVER (PARTITION BY d.DistributorName) AS DistributorTotalCases,
           SUM(d.QuantityCases) * 100.0 / SUM(SUM(d.QuantityCases)) OVER (PARTITION BY d.DistributorName) AS ContributionPct,
           DENSE_RANK() OVER (PARTITION BY d.DistributorName ORDER BY SUM(d.QuantityCases) DESC) AS RN
    FROM Dispatches d
    JOIN ProductionBatches pb ON pb.BatchID = d.BatchID
    JOIN Products p ON p.ProductID = pb.ProductID
    GROUP BY d.DistributorName, p.ProductFamily
)
SELECT DistributorName, ProductFamily, TotalCases, DistributorTotalCases, ContributionPct, RN
FROM DistributorMix
WHERE RN <= 2
ORDER BY DistributorName, RN, ProductFamily;

-- 24
WITH Received AS
(
    SELECT pol.MaterialID, SUM(pol.ReceivedQty) AS ReceivedQty
    FROM PurchaseOrderLines pol
    JOIN PurchaseOrders po ON po.POID = pol.POID
    WHERE YEAR(po.PODate) = 2026
    GROUP BY pol.MaterialID
),
Used AS
(
    SELECT u.MaterialID, SUM(u.ActualQty) AS UsedQty
    FROM BatchMaterialUsage u
    JOIN ProductionBatches b ON b.BatchID = u.BatchID
    WHERE YEAR(b.ProductionDate) = 2026
    GROUP BY u.MaterialID
)
SELECT m.MaterialCode, m.MaterialName, r.ReceivedQty, u.UsedQty,
       r.ReceivedQty - u.UsedQty AS NetBalanceQty,
       ROUND(u.UsedQty * 100.0 / r.ReceivedQty, 2) AS UsageToReceiptPct,
       RANK() OVER (ORDER BY r.ReceivedQty - u.UsedQty ASC) AS ShortageRank
FROM Used u
JOIN Received r ON r.MaterialID = u.MaterialID
JOIN Materials m ON m.MaterialID = u.MaterialID
WHERE u.UsedQty > r.ReceivedQty AND r.ReceivedQty > 0
ORDER BY ShortageRank;
