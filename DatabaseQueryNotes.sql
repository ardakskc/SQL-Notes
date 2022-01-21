--Lokasyon Tablosu
CREATE TABLE Lokasyon(
	Loc_ID Numeric Primary Key,
	Il varchar(15),
	Ilce varchar(15),
	Mahalle varchar(15),
	Sokak varchar(15),
	Posta_Kodu varchar(10)
);
--Bolum Tablosu
CREATE TABLE Bolum(
	Bolum_ID Numeric Primary Key,
	Ad varchar(50),
	Fakulte varchar(30),
	LokasyonID Numeric,
	constraint fk_B_LocID foreign key (LokasyonID) references Lokasyon(Loc_ID) on delete cascade
);
--sirket Tablosu
CREATE TABLE Sirket(
	Sirket_ID Numeric Primary Key,
	Ad varchar(25),
	Sektor varchar(25),
	Telefon char(11),
	LokasyonID Numeric,
	constraint fk_S_LocID foreign key (LokasyonID) references Lokasyon(Loc_ID) on delete cascade
);
--Ilan Tablosu
CREATE TABLE Ilan(
	Ilan_ID Numeric Primary Key,
	Maas Numeric,
	Pozisyon varchar(25),
	Calisma_Tipi varchar(25),
	SirketID Numeric,
	constraint fk_I_SirketID foreign key (SirketID) references Sirket(Sirket_ID) on delete cascade,
	constraint c_Calisma check(Calisma_Tipi in ('Full', 'Part')),--Iki cesit calisma saati.
	constraint c_Maas check(Maas>4250)--Maas Asgariden az olamaz.
);
--Mezunlar Tablosu
CREATE TABLE Mezunlar(
	Mezun_ID Numeric Primary Key,
	Ad Varchar(20),
	Soyad Varchar(20),
	Cinsiyet char(1),
	Derece Varchar(20),
	Giris_Yil Integer,
	Mezun_Yil Integer,
	SirketID Numeric,
	Telefon char(11),
	Mail varchar(25),
	BolumID Numeric,
	LokasyonID Numeric,
	constraint fk_SirketID foreign key (SirketID) references Sirket(Sirket_ID) on delete cascade,
	constraint fk_LocID foreign key (LokasyonID) references Lokasyon(Loc_ID) on delete cascade,
	constraint fk_BolumID foreign key (BolumID) references Bolum(Bolum_ID) on delete cascade,
	constraint c_Derece check(Derece in ('Lisans', 'On Lisans','Yuksek Lisans', 'Doktora')),--Derece kisitt
	constraint c_Giris check(Giris_Yil>0 and Giris_Yil<2023),--Yil kisitlari
	constraint c_Mezun check(Mezun_Yil>0 and Mezun_Yil<2023)
);
--Basvuru Tablosu
CREATE TABLE Basvuru(
	Basvuru_ID Numeric Primary Key,
	MezunID Numeric,
	IlanID Numeric,
	Basvuru_Tarih Date,
	constraint fk_MezunID foreign key (MezunID) references Mezunlar(Mezun_ID) on delete cascade,
	constraint fk_IlanID foreign key (IlanID) references Ilan(Ilan_ID) on delete cascade
);
--Telefon numarasi kontrolU icin trigger
CREATE OR REPLACE FUNCTION Mezun_Giris_Fonk3()
RETURNS TRIGGER AS $$
BEGIN
IF ( length(new.Telefon) != 11) THEN
	RAISE EXCEPTION 'Telefon 11 karakterli olmali' ;
	RETURN null;
ELSE
	RETURN new;
END IF;

END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER Mezun_Tel
BEFORE INSERT
ON Mezunlar
FOR EACH ROW EXECUTE PROCEDURE Mezun_Giris_Fonk3();

--Cinsiyet girisleri icin kontrol triggeri
CREATE OR REPLACE FUNCTION Mezun_Giris_Fonk2()
RETURNS Trigger AS $$
Begin
	IF(new.Cinsiyet = 'k' OR new.Cinsiyet = 'e')THEN
		Return new;
	ELSE
		RAISE EXCEPTION 'Cinsiyet Hatali.';
		Return null;
	END IF;
END
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER Mezun_Giris2
Before Insert
On Mezunlar
For Each Row Execute Procedure Mezun_Giris_Fonk2();

--Mezun yili ve giris yili kontrol triggeri
CREATE OR REPLACE FUNCTION Mezun_Giris_Fonk()
RETURNS Trigger AS $$
Begin
	IF(new.Giris_Yil>= new.Mezun_Yil)THEN
		RAISE EXCEPTION 'Giris-Mezun Yili Hatali.';
		Return null;
	ELSE
		Return new;
	END IF;
END
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER Mezun_Giris
Before Insert
On Mezunlar
For Each Row Execute Procedure Mezun_Giris_Fonk();

--Tablo Idleri icin Sequence'ler
create sequence seq_Loc
minvalue 1
no maxvalue
increment by 1;

create sequence seq_Mezun
minvalue 1
no maxvalue
increment by 1;

create sequence seq_Bolum
minvalue 1
no maxvalue
increment by 1;

create sequence seq_Sirket
minvalue 1
no maxvalue
increment by 1;

create sequence seq_Ilan
minvalue 1
no maxvalue
increment by 1;

create sequence seq_Basvuru
minvalue 1
no maxvalue
increment by 1;

--Ilanlardaki Ortalama maastan yUksek teklif veren sirket idleri.
CREATE OR REPLACE FUNCTION	Average_Maas() 
RETURNS TABLE(
	Sirket_ID Numeric,
	Maas Numeric
	)
AS $$
	
DECLARE 
	ort_maas real;
BEGIN
	SELECT avg(A.Maas) into ort_maas
	From Ilan A;
	
	RETURN QUERY SELECT I.SirketID,avg(I.Maas)
			FROM Ilan I
			GROUP BY I.SirketID
			HAVING avg(I.Maas)>ort_maas;
END;
$$ LANGUAGE 'plpgsql';

--Ayni dOnemde okuyan Ogrencileri listeleyen fonksiyon.
CREATE OR REPLACE FUNCTION uie(giris Mezunlar.Giris_yil%type, cikis Mezunlar.Mezun_Yil%type)
RETURNS void AS $$
DECLARE
	cur CURSOR FOR  SELECT	M1.BolumID, M1.Ad, M1.Soyad
			FROM	Mezunlar M1
			WHERE	M1.Giris_Yil=giris
			INTERSECT
			SELECT	M2.BolumID,M2.Ad, M2.Soyad
			FROM	Mezunlar M2
			WHERE	M2.Mezun_Yil=cikis;
BEGIN
	FOR i IN cur LOOP
		RAISE INFO '% bolumunden % % ile ayni donemlerde okudunuz.',i.BolumID, i.Ad, i.Soyad;
	END LOOP;
END;
$$ LANGUAGE 'plpgsql';

--Idsi verilen bOlUmdeki mezunlari listeleyen fonksiyon
CREATE OR REPLACE FUNCTION Bolum_Mezun(b_id Bolum.Bolum_ID%type) 
RETURNS void AS $$
	
DECLARE 
	cur CURSOR FOR 	SELECT 	Mezun_ID, Ad, Soyad
			FROM	Mezunlar B
			WHERE	B.BolumID = b_id;

BEGIN
	FOR i IN cur LOOP
		RAISE INFO 'Mezun ID: % Mezun adi: % %', i.Mezun_ID, i.Ad, i.Soyad;
	END LOOP;
END
$$ LANGUAGE 'plpgsql';

--Idsi verilen sirketin ilanlarini listeleyen fonksiyon
CREATE OR REPLACE FUNCTION Sirket_Ilan(s_id Sirket.Sirket_ID%type)
RETURNS void AS $$

DECLARE
	cur CURSOR FOR	SELECT	Ilan_ID, Maas, Pozisyon, Calisma_Tipi
			FROM	Ilan I
			WHERE	s_id=I.SirketID
			ORDER BY Maas DESC;
BEGIN
	FOR i IN cur LOOP
		RAISE INFO 'Ilan ID: % Maas: % Pozisyon: % Calisma Tipi: %',i.Ilan_ID, i.Maas, i.Pozisyon, i.Calisma_Tipi;
	END LOOP;
END
$$ LANGUAGE 'plpgsql';

--Ismi verilen sirkette calisan mezunlari listeleyen fonksiyon
CREATE TYPE calisanlar AS (ID NUMERIC, isim VARCHAR(20), soyisim VARCHAR(20));

CREATE OR REPLACE FUNCTION Sirket_Mezun(sirketadi Sirket.Ad%type)

RETURNS calisanlar[] AS $$

DECLARE
	cur CURSOR FOR	SELECT	M.Mezun_ID,M.Ad,M.Soyad
			FROM	Sirket S, Mezunlar M
			WHERE	sirketadi=S.Ad AND S.Sirket_ID=M.SirketID;
	cal calisanlar[];
	i integer;
BEGIN
	i=1;
	RAISE INFO '% isimli sirkette calisan mezunlar:',sirketadi;
		FOR mezun IN cur LOOP
			RAISE INFO 'Mezun ID: % Mezun Adi: % %', mezun .Mezun_ID, mezun.Ad, mezun .Soyad;
			cal[i]=mezun;
			i=i+1;
		END LOOP;
	RETURN cal;
END;
$$ LANGUAGE 'plpgsql';

--Basvuru almis ilanlari listeleyen view
CREATE VIEW Basvuru_Ilan
AS
SELECT distinct i.Ilan_ID, i.Maas, i.Pozisyon, i.Calisma_Tipi, i.SirketID
FROM Ilan i, Basvuru b
WHERE i.Ilan_ID = b.IlanID;

--TABLO GIRIsLERI
insert into Lokasyon Values(nextval('seq_Loc'),'Istanbul','Esenler','Davutpasa','Davutpasa','34420');
insert into Lokasyon Values(nextval('seq_Loc'),'Hatay','DOrtyol','Sanayi','InOnU','31600');
insert into Lokasyon Values(nextval('seq_Loc'),'Istanbul','Besiktas','Barbaros','Yildiz','34349');
insert into Lokasyon Values(nextval('seq_Loc'),'Istanbul','KadikOy','ZUhtUpasa','Bagdat','34724');
insert into Lokasyon Values(nextval('seq_Loc'),'Istanbul','Kayisdagi','InOnU','DUzenli','34755');
insert into Lokasyon Values(nextval('seq_Loc'),'Konya','Meram','Necip Fazil','Yaka','42090');
insert into Lokasyon Values(nextval('seq_Loc'),'Ankara','cankaya','Kizilay','Sezenler','06430');
insert into Lokasyon Values(nextval('seq_Loc'),'Hatay','Antakya','Yeni Camii','Uzun carsi','31060');
insert into Lokasyon Values(nextval('seq_Loc'),'Adana','cukurova','Mahfesigmaz','Turgut Ozal','01173');
insert into Lokasyon Values(nextval('seq_Loc'),'Izmir','Konak','KUltUr','sehit Nevres','35220');

insert into bolum values(nextval('seq_bolum'),'Bilgisiyar MUhendisligi','Elektrik Elektronik FakUltesi',1);
insert into bolum values(nextval('seq_bolum'),'Kontrol Otomasyon','Elektrik Elektronik FakUltesi',1);
insert into bolum values(nextval('seq_bolum'),'Elektrik MUhendisligi','Elektrik Elektronik FakUltesi',1);
insert into bolum values(nextval('seq_bolum'),'Elektronik ve Haberlesme','Elektrik Elektronik FakUltesi',1);
insert into bolum values(nextval('seq_bolum'),'Insaat MUhendisligi','Insaat FakUltesi',1);
insert into bolum values(nextval('seq_bolum'),'Psikoloji','Egitim FakUltesi',1);
insert into bolum values(nextval('seq_bolum'),'Fizik','Fen Edebiyat FakUltesi',1);
insert into bolum values(nextval('seq_bolum'),'MolekUler Biyoloji ve Genetik','Fen Edebiyat FakUltesi',1);
insert into bolum values(nextval('seq_bolum'),'Matematik MUhendisligi','Fen Edebiyat FakUltesi',1);
insert into bolum values(nextval('seq_bolum'),'Kimya MUhendisligi','Kimya Metalurji FakUltesi',1);

insert into sirket values(nextval('seq_sirket'),'Kiymaci Yazilim','Yazilim','03267129300',1);
insert into sirket values(nextval('seq_sirket'),'Kasikci Holding','Bilisim','01234567891',2);
insert into sirket values(nextval('seq_sirket'),'Vestel','Elektronik','01234567892',3);
insert into sirket values(nextval('seq_sirket'),'Vodafone','Iletisim','01234567893',4);
insert into sirket values(nextval('seq_sirket'),'Baldede Insaat','Insaat','01234567894',5);
insert into sirket values(nextval('seq_sirket'),'Atilgan Hastanesi','Saglik','01234567895',6);
insert into sirket values(nextval('seq_sirket'),'Yildiz Teknik Univ','Egitim','01234567896',7);
insert into sirket values(nextval('seq_sirket'),'Abdi Ibrahim','Saglik','01234567897',8);
insert into sirket values(nextval('seq_sirket'),'Mertoglu Yazilim','Bilisim','01234567898',9);
insert into sirket values(nextval('seq_sirket'),'Ulker','Gida','01234567899',10);

insert into mezunlar values(nextval('seq_mezun'),'Ahmethan','Kiymaci','e','Lisans',2012,2021,1,'05393278338','akiymaci@gmail.com',1,1);
insert into mezunlar values(nextval('seq_mezun'),'Arda','Kasikci','e','Yuksek Lisans',2014,2018,2,'05393278310','akasikci@gmail.com',2,2);
insert into mezunlar values(nextval('seq_mezun'),'Elif','Mertoglu','k','Yuksek Lisans',2003,2009,3,'05393278312','emertoglu@gmail.com',3,3);
insert into mezunlar values(nextval('seq_mezun'),'Aytug','Baldede','k','On Lisans',2000,2007,null,'05393278313','abaldede@gmail.com',4,4);
insert into mezunlar values(nextval('seq_mezun'),'Ege','OztUrk','e','On Lisans',2004,2008,5,'05393278311','eozturk@gmail.com',5,5);
insert into mezunlar values(nextval('seq_mezun'),'Berk','Sicak','e','On Lisans',2012,2021,null,'05393278314','bsicak@gmail.com',6,6);
insert into mezunlar values(nextval('seq_mezun'),'Bengi','Yurdusever','k','On Lisans',2011,2017,7,'05393278316','byurdusever@gmail.com',7,7);
insert into mezunlar values(nextval('seq_mezun'),'Enes','Bakir','e','On Lisans',1996,2001,null,'05393278315','ebakir@gmail.com',8,8);
insert into mezunlar values(nextval('seq_mezun'),'Batuhan','Ozbay','e','On Lisans',2000,2004,9,'05393278317','bozbay@gmail.com',9,9);
insert into mezunlar values(nextval('seq_mezun'),'Urfet','Atilgan','e','On Lisans',2006,2011,null,'05393278318','uatilgan@gmail.com',10,10);

insert into Ilan values(nextval('seq_Ilan'),12000,'Yazilim MUhendisi','Full',9);
insert into Ilan values(nextval('seq_Ilan'),8000,'Doktor','Full',6);
insert into Ilan values(nextval('seq_Ilan'),7500,'Gida MUhendisi','Full',10);
insert into Ilan values(nextval('seq_Ilan'),6000,'Insaat MUhendisi','Full',5);
insert into Ilan values(nextval('seq_Ilan'),4750,'Grafik Tasarimci','Part',4);
insert into Ilan values(nextval('seq_Ilan'),9000,'Kimya MUhendisi','Full',8);
insert into Ilan values(nextval('seq_Ilan'),8750,'Bilgisayar MUhendisi','Full',1);
insert into Ilan values(nextval('seq_Ilan'),11500,'Elektronik MUhendisi','Full',3);
insert into Ilan values(nextval('seq_Ilan'),14000,'Grup MUdUrU','Full',2);
insert into Ilan values(nextval('seq_Ilan'),9000,'Arastirma GOrevlisi','Part',7);

insert into basvuru values(nextval('seq_basvuru'),1,1,'2021-12-25');
insert into basvuru values(nextval('seq_basvuru'),2,2,'2021-11-21');
insert into basvuru values(nextval('seq_basvuru'),3,3,'2021-09-14');
insert into basvuru values(nextval('seq_basvuru'),4,4,'2021-08-22');
insert into basvuru values(nextval('seq_basvuru'),5,5,'2021-12-07');
insert into basvuru values(nextval('seq_basvuru'),6,6,'2021-12-30');
insert into basvuru values(nextval('seq_basvuru'),7,7,'2021-10-14');
insert into basvuru values(nextval('seq_basvuru'),8,8,'2021-07-28');
insert into basvuru values(nextval('seq_basvuru'),9,9,'2021-11-30');
insert into basvuru values(nextval('seq_basvuru'),10,10,'2021-11-24');

--Fonksiyon calistirilmasi
select uie(2012,2021);
select Bolum_Mezun(4);
select Sirket_Ilan(3);
select Sirket_Mezun('Kasikci Holding');
SELECT Average_Maas();
