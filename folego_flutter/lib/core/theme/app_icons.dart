import 'package:flutter/widgets.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Sistema oficial de ícones do Fôlego.
///
/// Fonte de verdade:
/// Tabler Icons — Outline.
///
/// Regra:
/// - categoria principal = ícone principal + cor da família
/// - subcategoria = ícone próprio + HERDA a cor da categoria principal
/// - telas devem usar AppIcons em vez de TablerIcons diretamente
abstract final class AppIcons {
  // ---------------------------------------------------------------------------
  // NAVEGAÇÃO PRINCIPAL
  // ---------------------------------------------------------------------------

  static const IconData home = TablerIcons.home2;
  static const IconData transactions = TablerIcons.list;
  static const IconData plan = TablerIcons.chartPie;
  static const IconData wallet = TablerIcons.wallet;
  static const IconData profile = TablerIcons.user;

  // ---------------------------------------------------------------------------
  // AÇÕES RÁPIDAS
  // ---------------------------------------------------------------------------

  static const IconData expense = TablerIcons.receipt2;
  static const IconData income = TablerIcons.plus;
  static const IconData goals = TablerIcons.targetArrow;
  static const IconData journal = TablerIcons.notebook;

  // ===========================================================================
  // CATEGORIAS PRINCIPAIS
  // ===========================================================================

  static const IconData categoryUnclassified = TablerIcons.category;

  static const IconData categoryFood = TablerIcons.toolsKitchen2;

  static const IconData categorySubscriptions = TablerIcons.repeat;

  static const IconData categoryBeauty = TablerIcons.sparkles;

  static const IconData categoryShopping = TablerIcons.shoppingBag;

  static const IconData categoryHouseholdBills = TablerIcons.bolt;

  static const IconData categoryDebt = TablerIcons.wallet;

  static const IconData categoryEducation = TablerIcons.school;

  static const IconData categoryFinance = TablerIcons.buildingBank;

  static const IconData categoryLeisure = TablerIcons.confetti;

  static const IconData categoryHousing = TablerIcons.home;

  static const IconData categoryGifts = TablerIcons.gift;

  static const IconData categoryHealth = TablerIcons.heartRateMonitor;

  static const IconData categoryTransport = TablerIcons.car;

  static const IconData categoryClothing = TablerIcons.shirt;

  static const IconData categoryTravel = TablerIcons.plane;

  static const IconData categoryFamily = TablerIcons.heartHandshake;

  static const IconData categoryPets = TablerIcons.heart;

  static const IconData categoryInsurance = TablerIcons.fileCheck;

  static const IconData categoryOther = TablerIcons.dots;

  // ===========================================================================
  // ALIMENTAÇÃO
  // ===========================================================================

  static const IconData foodSupermarket = TablerIcons.shoppingCart;

  static const IconData foodRestaurant = TablerIcons.toolsKitchen;

  static const IconData foodDelivery = TablerIcons.motorbike;

  static const IconData foodCafe = TablerIcons.coffee;

  // ===========================================================================
  // MORADIA
  // ===========================================================================

  static const IconData housingRent = TablerIcons.home;

  static const IconData housingCondo = TablerIcons.building;

  static const IconData housingMaintenance = TablerIcons.tools;

  static const IconData housingFurniture = TablerIcons.armchair;

  // ===========================================================================
  // CONTAS DA CASA
  // ===========================================================================

  static const IconData billsEnergy = TablerIcons.bolt;

  static const IconData billsWater = TablerIcons.droplet;

  static const IconData billsGas = TablerIcons.flame;

  static const IconData billsInternet = TablerIcons.wifi;

  static const IconData billsPhone = TablerIcons.phone;

  // ===========================================================================
  // TRANSPORTE
  // ===========================================================================

  static const IconData transportFuel = TablerIcons.gasStation;

  static const IconData transportRide = TablerIcons.car;

  static const IconData transportPublic = TablerIcons.bus;

  static const IconData transportParking = TablerIcons.parking;

  static const IconData transportToll = TablerIcons.road;

  static const IconData transportMaintenance = TablerIcons.tools;

  // ===========================================================================
  // SAÚDE
  // ===========================================================================

  static const IconData healthPharmacy = TablerIcons.pill;

  static const IconData healthConsultation = TablerIcons.stethoscope;

  static const IconData healthExams = TablerIcons.microscope;

  static const IconData healthTherapy = TablerIcons.brain;

  static const IconData healthGym = TablerIcons.dumbbell;

  // ===========================================================================
  // EDUCAÇÃO
  // ===========================================================================

  static const IconData educationCollege = TablerIcons.school;

  static const IconData educationCourse = TablerIcons.certificate;

  static const IconData educationBooks = TablerIcons.books;

  // ===========================================================================
  // LAZER
  // ===========================================================================

  static const IconData leisureCinema = TablerIcons.movie;

  static const IconData leisureOuting = TablerIcons.mapPin;

  static const IconData leisureEvent = TablerIcons.ticket;

  static const IconData leisureHobby = TablerIcons.palette;

  static const IconData leisureGames = TablerIcons.deviceGamepad;

  // ===========================================================================
  // ASSINATURAS
  // ===========================================================================

  static const IconData subscriptionStreaming = TablerIcons.deviceTv;

  static const IconData subscriptionMusic = TablerIcons.music;

  static const IconData subscriptionApps = TablerIcons.apps;

  static const IconData subscriptionSoftware = TablerIcons.code;

  static const IconData subscriptionOther = TablerIcons.repeat;

  // ===========================================================================
  // COMPRAS
  // ===========================================================================

  static const IconData shoppingOnline = TablerIcons.shoppingCart;

  static const IconData shoppingHome = TablerIcons.package;

  static const IconData shoppingElectronics = TablerIcons.deviceLaptop;

  static const IconData shoppingMarketplace = TablerIcons.buildingStore;

  static const IconData shoppingOther = TablerIcons.shoppingBag;

  // ===========================================================================
  // VESTUÁRIO
  // ===========================================================================

  static const IconData clothingClothes = TablerIcons.shirt;

  static const IconData clothingShoes = TablerIcons.shoe;

  static const IconData clothingAccessories = TablerIcons.eyeglass2;

  // ===========================================================================
  // BELEZA E CUIDADOS
  // ===========================================================================

  static const IconData beautyHair = TablerIcons.scissors;

  static const IconData beautyCosmetics = TablerIcons.brush;

  static const IconData beautyAesthetics = TablerIcons.sparkles;

  static const IconData beautyPersonalCare = TablerIcons.heart;

  // ===========================================================================
  // PRESENTES
  // ===========================================================================

  static const IconData giftsPresent = TablerIcons.gift;

  static const IconData giftsCelebration = TablerIcons.confetti;

  static const IconData giftsDonation = TablerIcons.heartHandshake;

  // ===========================================================================
  // FINANCEIRO
  // ===========================================================================

  static const IconData financeBankFee = TablerIcons.buildingBank;

  static const IconData financeInterest = TablerIcons.percentage;

  static const IconData financeTax = TablerIcons.receiptTax;

  static const IconData financeAdjustment = TablerIcons.arrowsExchange;

  // ===========================================================================
  // DÍVIDAS E EMPRÉSTIMOS
  // ===========================================================================

  static const IconData debtLoan = TablerIcons.cashBanknote;

  static const IconData debtInstallment = TablerIcons.calendarDollar;

  static const IconData debtFinancing = TablerIcons.fileDollar;

  static const IconData debtAgreement = TablerIcons.fileCheck;

  // ===========================================================================
  // COMPATIBILIDADE COM O CÓDIGO ATUAL
  // ===========================================================================

  static const IconData food = categoryFood;
  static const IconData house = categoryHousing;
  static const IconData car = categoryTransport;
  static const IconData bus = transportPublic;
  static const IconData transport = categoryTransport;
  static const IconData health = categoryHealth;

  // ---------------------------------------------------------------------------
  // FINANCEIRO / CARTEIRA
  // ---------------------------------------------------------------------------

  static const IconData creditCard = TablerIcons.creditCard;

  static const IconData account = TablerIcons.buildingBank;

  static const IconData benefit = TablerIcons.ticket;

  static const IconData cash = TablerIcons.cash;

  static const IconData transfer = TablerIcons.arrowsExchange;

  static const IconData calendar = TablerIcons.calendar;

  static const IconData recurring = TablerIcons.repeat;

  static const IconData receipt = TablerIcons.receipt;

  static const IconData debt = TablerIcons.fileInvoice;

  // ---------------------------------------------------------------------------
  // PERFIL / CONFIGURAÇÕES
  // ---------------------------------------------------------------------------

  static const IconData settings = TablerIcons.settings;

  static const IconData achievements = TablerIcons.award;

  static const IconData savingsGoal = TablerIcons.pigMoney;

  static const IconData notifications = TablerIcons.bell;

  static const IconData lightTheme = TablerIcons.sun;

  static const IconData darkTheme = TablerIcons.moon;

  static const IconData systemTheme = TablerIcons.deviceDesktop;

  static const IconData language = TablerIcons.language;

  static const IconData privacy = TablerIcons.shieldLock;

  static const IconData exportData = TablerIcons.fileExport;

  static const IconData logout = TablerIcons.logout;

  // ---------------------------------------------------------------------------
  // INTERFACE
  // ---------------------------------------------------------------------------

  static const IconData flame = TablerIcons.flame;

  static const IconData add = TablerIcons.plus;

  static const IconData edit = TablerIcons.edit;

  static const IconData delete = TablerIcons.trash;

  static const IconData close = TablerIcons.x;

  static const IconData back = TablerIcons.arrowLeft;

  static const IconData forward = TablerIcons.arrowRight;

  static const IconData chevronRight = TablerIcons.chevronRight;

  static const IconData chevronLeft = TablerIcons.chevronLeft;

  static const IconData chevronDown = TablerIcons.chevronDown;

  static const IconData check = TablerIcons.check;

  static const IconData info = TablerIcons.infoCircle;

  static const IconData warning = TablerIcons.alertTriangle;

  static const IconData search = TablerIcons.search;

  static const IconData filter = TablerIcons.filter;

  static const IconData refresh = TablerIcons.refresh;

  static const IconData adjustments = TablerIcons.adjustments;

  static const IconData chartLine = TablerIcons.chartLine;

  static const IconData eye = TablerIcons.eye;

  static const IconData eyeOff = TablerIcons.eyeOff;
}
