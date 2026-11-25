/// Design-size layout tokens for the whole app (393×852 phone baseline).
///
/// Scale at the call site with ScreenUtil:
/// horizontal width/gap → `.w`, vertical height/gap → `.h`,
/// font/icon → `.sp`, corner radius → `.r`.
abstract final class AppLayout {
  // --- Shared spacing ------------------------------------------------------

  static const gap2 = 2.0;
  static const gap3 = 3.0;
  static const gap4 = 4.0;
  static const gap6 = 6.0;
  static const gap8 = 8.0;
  static const gap10 = 10.0;
  static const gap12 = 12.0;
  static const gap14 = 14.0;
  static const gap16 = 16.0;
  static const gap18 = 18.0;
  static const gap20 = 20.0;
  static const gap22 = 22.0;
  static const gap24 = 24.0;
  static const gap28 = 28.0;
  static const gap32 = 32.0;
  static const gap36 = 36.0;
  static const gap40 = 40.0;
  static const gap44 = 44.0;
  static const gap48 = 48.0;
  static const gap52 = 52.0;
  static const gap56 = 56.0;
  static const gap72 = 72.0;
  static const gap92 = 92.0;

  // --- Shared radii --------------------------------------------------------

  static const radiusXs = 2.0;
  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 12.0;
  static const radiusXl = 14.0;
  static const radius2xl = 16.0;
  static const radius3xl = 20.0;
  static const radiusSheet = 28.0;
  static const radiusPill = 50.0;

  // --- Shared typography (design pt) -----------------------------------------

  static const text2xs = 7.5;
  static const textXs = 9.0;
  static const textSm = 10.0;
  static const textMd = 11.0;
  static const textBase = 12.0;
  static const textLg = 13.0;
  static const textXl = 14.0;
  static const text2xl = 15.0;
  static const text3xl = 16.0;
  static const text4xl = 18.0;
  static const text5xl = 20.0;
  static const text6xl = 22.0;
  static const textWordmark = 19.0;

  /// The largest step: the heading a renewal opens the paywall with. The
  /// connection status under the dial sits a step below it, so the dial and
  /// not its caption is what the home screen leads with.
  static const text7xl = 24.0;

  // --- Shared scrim --------------------------------------------------------

  /// How dark the world goes behind anything raised over it.
  ///
  /// One value for every dialog and sheet. There used to be five — 0.35, 0.35,
  /// 0.45, 0.55, 0.62 — two of them named here, one a private const, two
  /// written at the call site, and no two popups occluded the screen by the
  /// same amount. This is the picker's old value, which is the sheet the app
  /// raises most and the one the others were judged against.
  static const scrimAlpha = 0.55;

  // --- Shared sheets -------------------------------------------------------

  /// The grip at a sheet's top edge, drawn by `AppSheetHandle` for every
  /// sheet that has one.
  static const sheetHandleWidth = gap36;
  static const sheetHandleHeight = gap4;
  static const sheetHandleRadius = radiusXs;
  static const sheetHandleTop = gap10;

  // --- Shared controls -----------------------------------------------------

  /// One geometry for the primary action, wherever a screen asks for one.
  ///
  /// There used to be six: vertical padding of 8, 12 or 14 and a corner radius
  /// of 12 or 14, spread over the component and the five places that wrote
  /// their own `styleFrom` beside it. Nothing chose between them — each site
  /// picked what looked right on the screen being built that day.
  static const buttonRadius = radiusXl;
  static const buttonPadV = gap14;
  static const buttonPadH = gap20;
  static const buttonLabel = text2xl;

  /// A compact action, for the pair at the foot of a dialog where a
  /// full-width button would outweigh the question above it.
  static const buttonCompactPadV = gap8;
  static const buttonCompactPadH = gap16;
  static const buttonCompactLabel = textLg;

  // --- Main: home panel (IP + server row) ----------------------------------

  static const mainPanelOuterInset = gap20;
  static const mainPanelContentWidth = 300.0;
  static const mainPanelInnerPaddingH = gap14;
  static const mainPanelInnerPaddingV = gap12;
  static const mainPanelCornerRadius = radius2xl;
  static const mainPanelIpContentHeight = 74.0;
  static const mainPanelGlassWidth =
      mainPanelContentWidth + mainPanelInnerPaddingH * 2;

  // --- Main: screen vertical rhythm ----------------------------------------

  static const mainAppBarToIp = gap20;
  static const mainIpToDial = gap24;
  static const mainDialToTextGap = gap24;

  // --- Main: app bar -------------------------------------------------------

  static const mainAppBarEdgeInset = gap20;
  static const mainAppBarTopInset = gap36;
  static const mainAppBarWordmarkHeight = gap40;
  static const mainAppBarChannelRadius = 13.0;

  /// The support button's insets either side of its plane and label, the
  /// label side a step wider so the pill does not look clipped after the word.
  static const mainAppBarChannelPadStart = gap12;
  static const mainAppBarChannelPadEnd = gap14;
  static const mainAppBarChannelLabelGap = gap8;
  static const mainAppBarChannelLabel = textLg;
  static const mainAppBarWordmarkTracking = 4.18;
  static const mainAppBarPlanBadgeGap = gap10;

  // --- Plan badge: the app bar and the paywall ----------------------------

  static const planBadgeRadius = gap6;
  static const planBadgePadH = gap8;
  static const planBadgeTracking = 1.4;
  static const planBadgeHeight = gap20;
  static const planBadgeFont = textSm;

  // --- Main: nav bar -------------------------------------------------------

  static const mainNavBottomInset = 22.0;
  static const mainNavBreathingGap = gap12;
  static const mainNavSeatHeight = gap52;
  static const mainNavPadding = gap6;
  static const mainNavGap = gap4;
  static const mainNavRestingWidth = 64.0;
  static const mainNavSelectedGrowth = gap18;
  static const mainNavRestingGlyph = gap22;
  static const mainNavSelectedGlyphGrowth = 0.0;
  static const mainNavRadius = 26.0;
  static const mainNavSeatRadius = gap20;

  /// How far past the glyph's top corner the settings tab's update dot sits.
  static const mainNavUpdateDotOverhang = gap2;

  static const mainNavHeight = mainNavSeatHeight + mainNavPadding * 2;
  static const mainNavFootprint = mainNavBottomInset + mainNavHeight;
  static const mainNavClearance = mainNavFootprint + mainNavBreathingGap;

  // --- Main: connection dial -----------------------------------------------

  static const mainDialSize = 180.0;

  /// The dial on the launch window, in logical pixels and never scaled: the
  /// platform draws it before ScreenUtil knows the screen. On a cold start
  /// the app's first frames show it at this size too, and carry it from the
  /// window's centre into the home dial's place.
  static const launchDialSize = mainDialSize;

  /// Android 12 and up hands the launch icon a canvas of this size and shows
  /// only its inner circle. Every platform's launch dial is cut to that
  /// circle, so it reads the same on each.
  static const launchIconCanvas = 288.0;
  static const launchShownCircle = launchIconCanvas * 2 / 3;

  /// The bird at the centre, by height: the artwork is taller than it is
  /// wide.
  static const mainDialBirdHeight = 100.0;

  /// How wide the bird's edges are, both the ones that catch the light and
  /// the ones that fall away from it.
  static const mainDialBirdEdge = 1.5;

  /// How far the glow round a lit streak spreads.
  static const mainDialStreakGlow = 2.4;

  static const mainDialRingWidth = 1.5;

  /// The dial's own light round it while it reports a status: close to the
  /// glass, so it reads as the rim lit up rather than as a halo.
  static const mainDialGlowSpread = gap2;
  static const mainDialGlowBlur = gap28;

  // --- Main: server row ----------------------------------------------------

  /// The line under the server saying how the connect will be made.
  static const homeSettingsLinePadV = gap12;
  static const homeSettingsLineGap = gap10;
  static const homeSettingsLineGlyph = gap16;
  static const homeSettingsLineText = textLg;

  static const mainServerRowPointerBox = gap28;
  static const mainServerRowPointerRadius = gap8;
  static const mainServerRowGap = gap12;
  static const mainServerRowLeadingBox = gap40;
  static const mainServerRowLeadingRadius = radiusLg;
  static const mainServerRowLeadingGlyph = gap20;
  static const mainServerRowTitleSize = text2xl;
  static const mainServerRowSubtitleSize = textMd;
  static const mainServerRowTitleToSubtitle = gap3;
  static const mainServerRowTrailingSize = radius2xl;
  static const mainServerRowSpinnerSize = 18.0;
  static const mainServerRowSpinnerStroke = 2.0;

  // --- Main: connection info (IP + ping) -----------------------------------

  static const mainIpFlagBox = 32.0;

  /// The column every mark down the panel's leading edge sits in.
  ///
  /// The flag tile sets it, because the tile is the widest thing that can
  /// stand there and the only one that is a filled shape. Everything under
  /// it — the speed glyph, the danger glyph on a ping that failed, the info
  /// glyph on a lookup that failed — takes the same box and centres in it,
  /// so the marks share a centre line and every line of text in the panel
  /// starts at the same place.
  ///
  /// Sized to their own glyphs instead, each row hung off its own gutter:
  /// the 14pt speedometer sat 9pt inside the tile's centre, and the reading
  /// started 22pt inside the address above it.
  static const mainIpLeadingGutter = mainIpFlagBox;
  static const mainIpFlagBoxRadius = 9.0;
  static const mainIpFlagEmoji = gap20;
  static const mainIpGap = gap10;
  static const mainIpAddressSize = textXl;
  static const mainIpAddressSpacing = 0.4;
  static const mainIpBadgeGap = gap6;
  static const mainIpBadgePadH = 5.0;
  static const mainIpBadgePadV = 2.0;
  static const mainIpBadgeRadius = radiusSm;
  static const mainIpBadgeText = text2xs;
  static const mainIpCountryGap = gap3;
  static const mainIpCountrySize = textMd;
  static const mainIpSectionGap = gap8;
  static const mainIpDividerGap = gap6;
  static const mainIpCheckPadding = gap4;
  static const mainIpCheckIcon = gap12;
  static const mainIpErrorIcon = 13.0;
  static const mainIpErrorGap = mainIpGap;
  static const mainIpErrorText = textMd;
  static const mainIpBarWidthAddress = 120.0;
  static const mainIpBarWidthCountry = 80.0;
  static const mainIpBarWidthPing = 72.0;
  static const mainIpBarRadius = radiusSm;
  static const mainIpLineHeight = 1.25;

  /// The two actions a tunnel that stopped carrying traffic offers, laid in
  /// the ping row's place. Kept to that row's height so the card's fixed box
  /// holds them: 32 for the warning row, 8 + 1 + 6 for the gap, the divider
  /// and the gap under it, and this.
  static const mainStallActionHeight = 26.0;
  static const mainStallActionGap = gap8;
  static const mainStallActionPadH = gap12;
  static const mainStallActionRadius = radiusMd;
  static const mainStallActionText = textBase;
  static const mainStallGlyph = gap16;

  static const mainPingIcon = textXl;
  static const mainPingGap = mainIpGap;
  static const mainPingValueSize = textMd;
  static const mainPingIdleText = textSm;
  static const mainPingErrorIcon = gap12;
  static const mainPingErrorGap = mainIpGap;
  static const mainPingErrorText = textXs;
  static const mainPingRefreshIcon = textXl;

  /// The box the refresh glyph sits in, which is the footprint of the
  /// connected tick in the row above rather than the glyph's own size.
  ///
  /// The two are the only things in that column and they sit one above the
  /// other, so the eye lines them up by their centres. Sizing both to their
  /// glyphs left the tick's disc — a glyph plus its padding — three points
  /// wider than the bare refresh, and both flush to the trailing edge, so
  /// their centres never met. Derived rather than typed out, because the
  /// number is only ever right while it equals the thing above it.
  static const mainPingRefreshSlot = mainIpCheckIcon + 2 * mainIpCheckPadding;

  static const mainPingBarRadius = radiusSm;
  static const mainPingIconRadius = radiusSm;

  // --- Main: server picker sheet -------------------------------------------

  static const mainPickerHeightFraction = 0.72;
  static const mainPickerRadius = radiusSheet;
  static const mainPickerHandleToList = gap14;

  // --- Premium -------------------------------------------------------------

  static const premiumCardRadius = radius3xl;
  static const premiumCardPad = radius2xl;
  static const premiumSectionGap = 18.0;
  static const premiumRowGap = gap8;
  static const premiumInnerRadius = radiusLg;
  static const premiumChipRadius = radiusLg;
  static const premiumServerIconSize = gap40;
  static const premiumHeaderButtonSize = gap40;
  static const premiumConfigDotSize = gap8;
  static const premiumPingShimmerHeight = gap14;
  static const premiumPingLabelSize = textMd;
  static const premiumPingIconSize = textXl;
  static const premiumPingIconGap = gap3;
  static const premiumListEmptyIcon = gap56;
  static const premiumDeviceRowRadius = gap6;
  static const premiumDialogIconPad = gap14;
  static const premiumDialogActionRadius = radiusLg;

  // Screen frame
  static const premiumScreenPadH = gap20;
  static const premiumListTopGap = gap8;

  // Glass card
  static const premiumCardInnerPad = gap20;

  // Server card
  static const premiumServerCardPadH = gap14;
  static const premiumServerCardPadV = 13.0;
  static const premiumServerCardGap = gap12;
  static const premiumServerCardLabelGap = gap3;
  static const premiumServerCardBadgeGap = gap8;
  static const premiumServerCardGlyph = gap16;
  static const premiumServerCardBodyPadH = gap14;
  static const premiumServerCardBodyGap = gap4;

  // Servers list
  static const premiumListPadH = gap20;
  static const premiumListHeaderGap = gap14;
  static const premiumListFlag = gap48;
  static const premiumListBottomPad = gap12;
  static const premiumListRowGap = gap10;
  static const premiumNoticePadH = gap14;
  static const premiumNoticePadV = gap12;
  static const premiumNoticeGlyph = gap18;
  static const premiumNoticeGap = gap10;
  static const premiumNoticeLineGap = gap4;
  static const premiumNoticeBlockGap = gap8;
  static const premiumEmptyPadH = gap28;
  static const premiumEmptyGlyphGap = gap16;
  static const premiumEmptyActionGap = gap20;

  // Device row
  static const premiumDeviceRowPadH = gap12;
  static const premiumDeviceRowPadV = gap10;
  static const premiumDeviceGlyph = gap20;
  static const premiumDeviceGap = gap12;
  static const premiumDeviceLabelGap = gap2;
  static const premiumDeviceActionGap = gap8;
  static const premiumDeviceBadgePadH = gap8;
  static const premiumDeviceBadgePadV = gap4;
  static const premiumDeviceSpinner = gap18;
  static const premiumDeviceChipPadH = gap10;
  static const premiumDeviceChipPadV = gap6;

  // Config tile
  static const premiumConfigPadH = gap16;
  static const premiumConfigPadV = gap12;
  static const premiumConfigGap = gap12;
  static const premiumConfigBadgeGap = gap8;
  static const premiumConfigSpinner = gap18;
  static const premiumConfigBadgePadH = 7.0;
  static const premiumConfigBadgePadV = gap3;

  // Servers header
  static const premiumHeaderLabelGap = gap4;
  static const premiumHeaderSpinner = gap16;
  static const premiumHeaderGlyph = gap18;
  static const premiumHeaderTogglePadH = gap12;
  static const premiumHeaderToggleSpinner = gap14;
  static const premiumHeaderDisconnectGlyph = gap16;
  static const premiumHeaderDisconnectGap = gap6;

  // Login form
  static const premiumLoginTopGap = gap8;
  static const premiumLoginGap = gap12;
  static const premiumLoginAvatar = gap40;
  static const premiumLoginTitleGap = gap6;
  static const premiumLoginFieldGap = 18.0;
  static const premiumLoginBlockGap = gap16;
  static const premiumLoginHintGap = gap4;
  static const premiumLoginGlyph = gap18;

  // Connect dialogs
  static const premiumDialogPad = gap24;
  static const premiumDialogGlyph = gap32;
  static const premiumDialogTitleGap = gap16;
  static const premiumDialogBodyGap = gap10;
  static const premiumDialogActionGap = gap24;
  static const premiumDialogActionPadV = gap12;
  static const premiumDialogActionGutter = gap10;
  static const premiumDialogMark = gap18;

  // Paywall: a full page, its sides the account screen's, its controls at
  // least as large as a finger needs. Spaced to fit a typical phone without
  // scrolling; it still scrolls on a small screen or in large text.
  static const premiumPaywallPadH = gap20;
  static const premiumPaywallTopBar = gap48;
  static const premiumPaywallControl = gap44;
  static const premiumPaywallControlGlyph = gap18;
  static const premiumPaywallCloseGlyph = gap28;
  static const premiumPaywallBadgeGap = gap8;
  static const premiumPaywallTitleGap = gap8;
  static const premiumPaywallSectionGap = gap16;
  static const premiumPaywallCardRadius = radius3xl;
  static const premiumPaywallCellPadH = gap12;
  static const premiumPaywallCellPadV = gap8;
  static const premiumPaywallArtTile = gap32;
  static const premiumPaywallArt = gap24;
  static const premiumPaywallArtGap = gap10;
  static const premiumPaywallValueColumnShare = 0.3;
  static const premiumPaywallTick = gap18;
  static const premiumPaywallDevicesPad = gap12;
  static const premiumPaywallStepperRadius = radiusXl;
  static const premiumPaywallStepperGap = gap6;
  static const premiumPaywallCount = gap28;
  static const premiumPaywallPeriodsPad = gap12;
  static const premiumPaywallRowRadius = radius2xl;
  static const premiumPaywallRowPadH = gap14;
  static const premiumPaywallRowPadV = gap12;
  static const premiumPaywallRowGap = gap8;
  static const premiumPaywallCardLineGap = gap4;
  static const premiumPaywallRowRing = 1.5;
  static const premiumPaywallRadio = gap22;
  static const premiumPaywallChipPadH = gap8;
  static const premiumPaywallChipPadV = gap2;
  static const premiumPaywallBestValueRise = gap8;
  static const premiumPaywallBarPadTop = gap12;
  static const premiumPaywallBarPadBottom = gap8;
  static const premiumPaywallBarGap = gap6;
  static const premiumPaywallSpinner = gap24;
  static const premiumPaywallSpinnerStroke = 2.0;

  // Account panel
  static const premiumAccountGap = gap12;
  static const premiumAccountBlockGap = gap14;
  static const premiumAccountRowGap = gap10;
  static const premiumAccountAvatar = gap44;
  static const premiumAccountAvatarGlyph = gap22;
  static const premiumAccountAvatarGap = gap12;
  static const premiumAccountLabelGap = gap2;
  static const premiumAccountBadge = gap18;
  static const premiumAccountMetaGlyph = gap16;
  static const premiumAccountMetaGap = gap8;
  static const premiumAccountTickPad = gap4;
  static const premiumAccountTick = gap16;
  static const premiumAccountActionPadV = gap16;
  static const premiumAccountSpinner = gap20;
  static const premiumAccountNoteGap = gap8;
  static const premiumAccountSecondaryPadV = gap12;
  static const premiumAccountHintGap = gap4;

  // Secondary button
  static const premiumSecondaryGlyph = gap18;
  static const premiumSecondaryPadV = gap12;
  static const premiumFieldGlyph = gap20;

  // --- Premium: account tab ------------------------------------------------
  //
  // One to one with the account tab's design, in design points.

  static const premiumTabTopPad = gap22;

  // Primary action
  static const premiumCtaHeight = 54.0;
  static const premiumCtaRadius = radius2xl;
  static const premiumCtaLabel = 15.5;
  static const premiumCtaGlyph = gap16;
  static const premiumCtaGap = gap10;
  static const premiumCtaTopGap = gap18;
  static const premiumCtaCompactHeight = 50.0;
  static const premiumCtaCompactLabel = text2xl;

  // Account actions
  static const premiumActionHeight = gap48;
  static const premiumActionRadius = radiusXl;
  static const premiumActionGap = 9.0;
  static const premiumActionGlyph = gap16;
  static const premiumActionLabel = textXl;
  static const premiumActionsTopGap = gap14;
  static const premiumActionsBottomGap = 26.0;
  static const premiumActionsColumnGap = gap10;

  // Fields
  static const premiumFieldRadius = 15.0;
  static const premiumFieldPadV = 17.0;
  static const premiumFieldPadStart = gap16;
  static const premiumFieldPadEnd = gap14;
  static const premiumFieldIconGap = gap12;
  static const premiumFieldLabel = text2xl;
  static const premiumFieldEye = gap32;
  static const premiumFieldEyeGlyph = gap16;
  static const premiumFieldGap = gap10;
  static const premiumFieldFocusRim = 1.0;

  // Segmented control
  static const premiumSegmentHeight = 38.0;
  static const premiumSegmentPad = gap4;
  static const premiumSegmentRadius = radiusXl;
  static const premiumSegmentThumbRadius = gap10;
  static const premiumSegmentLabel = textXl;
  static const premiumSegmentBottomGap = gap18;

  // Sign-in header
  static const premiumEmblem = 76.0;
  static const premiumEmblemStep = gap10;
  static const premiumEmblemRadius = gap24;
  static const premiumEmblemMidRadius = gap18;
  static const premiumEmblemCoreRadius = gap12;
  static const premiumEmblemGlyph = gap18;
  static const premiumEmblemTopGap = gap4;
  static const premiumEmblemGap = gap20;
  static const premiumEyebrow = textMd;
  static const premiumEyebrowTracking = 1.76;
  static const premiumHeading = 26.0;
  static const premiumHeadingTracking = -0.26;
  static const premiumHeadingLineHeight = 1.15;
  static const premiumHeadingGap = gap8;
  static const premiumSub = 14.5;
  static const premiumSubLineHeight = 1.5;
  static const premiumSubBottomGap = gap22;
  static const premiumFine = 12.5;

  // Perks
  static const premiumPerkTopGap = gap22;
  static const premiumPerkGap = gap8;
  static const premiumPerkPadH = gap10;
  static const premiumPerkPadV = gap12;
  static const premiumPerkRadius = radiusXl;
  static const premiumPerkGlyph = gap16;
  static const premiumPerkLabel = textBase;

  // Strength meter
  static const premiumMeterHeight = gap3;
  static const premiumMeterGap = gap4;

  // Pass
  static const premiumPassRadius = gap24;
  static const premiumPassPad = gap20;
  static const premiumPassMinHeight = 206.0;
  static const premiumPassRings = 220.0;
  static const premiumPassRingsInset = 60.0;
  static const premiumPassLabel = 10.5;

  /// Tracking for the pass's corner label, in logical pixels; Latin script
  /// only, see `PremiumPassCard`.
  static const premiumPassLabelTracking = 1.89;
  static const premiumPassUserTopGap = gap18;
  static const premiumPassUser = text2xl;
  static const premiumPassUserGlyph = gap16;
  static const premiumPassUserGap = gap8;
  static const premiumPassUserEmailMaxChars = 28;
  static const premiumPassBottomTopGap = gap20;

  /// The days left on an entitled pass: the one figure the tab is about.
  static const premiumPassFigure = 44.0;
  static const premiumPassFigureTracking = -0.88;
  static const premiumPassFigureLineHeight = 0.9;
  static const premiumPassCaptionGap = gap8;
  static const premiumPassCaption = textBase;
  static const premiumPassDateGap = gap3;
  static const premiumPassDate = textXl;
  static const premiumPassChipPadStart = gap8;
  static const premiumPassChipPadEnd = 9.0;
  static const premiumPassChipPadV = gap4;
  static const premiumPassChipLabel = textBase;
  static const premiumPassDot = gap6;
  static const premiumPassDotGap = gap6;
  static const premiumPassTitle = 21.0;
  static const premiumPassTitleTopGap = gap16;
  static const premiumPassTitleGap = gap4;
  static const premiumPassSub = 13.5;
  static const premiumPassCtaTopGap = gap18;
  static const premiumPassTierPadH = gap8;
  static const premiumPassTierPadV = gap4;
  static const premiumPassTierRadius = gap6;
  static const premiumPassTierLabel = textSm;
  static const premiumPassTierTracking = 1.4;
  static const premiumPassDash = gap6;
  static const premiumPassDashGap = gap4;
  static const premiumPassSpinner = gap16;

  // Devices
  static const premiumSectionHead = text2xl;
  static const premiumSectionHeadGap = gap12;
  static const premiumSlotWidth = gap18;
  static const premiumSlotHeight = gap6;
  static const premiumSlotRadius = gap3;
  static const premiumSlotGap = gap4;
  static const premiumSlotsLabelGap = gap8;
  static const premiumSlotsLabel = textBase;
  static const premiumDeviceCardPad = gap14;
  static const premiumDeviceCardRadius = gap18;
  static const premiumDeviceCardGap = gap14;
  static const premiumDeviceListGap = gap10;
  static const premiumDeviceIconBox = 42.0;
  static const premiumDeviceIconRadius = 13.0;
  static const premiumDeviceName = text2xl;
  static const premiumDeviceSub = 11.5;
  static const premiumDeviceSubGap = gap3;
  static const premiumDeviceTagPadH = 9.0;
  static const premiumDeviceTagPadV = 5.0;
  static const premiumDeviceTagRadius = gap8;
  static const premiumDeviceTagLabel = 11.5;

  // Binding note and delete
  static const premiumNoteTopGap = gap12;
  static const premiumNotePadH = gap14;
  static const premiumNotePadV = gap12;
  static const premiumNoteRadius = radiusXl;
  static const premiumNoteGap = gap12;
  static const premiumNoteGlyph = gap16;
  static const premiumNoteLabel = premiumFine;
  static const premiumNoteLineHeight = 1.5;
  static const premiumDangerTopGap = 26.0;
  static const premiumDangerHeight = gap44;
  static const premiumDangerRadius = radiusLg;
  static const premiumDangerLabel = premiumPassSub;
  static const premiumDangerGap = gap8;
  static const premiumDangerGlyph = gap16;

  // --- Settings ------------------------------------------------------------

  static const settingsScreenInsetH = gap20;
  static const settingsTabRadius = radiusXl;
  static const settingsTabIndicatorRadius = radiusLg;
  static const settingsChipRadius = radiusMd;
  static const settingsFieldRadius = radiusLg;
  static const settingsDialogRadius = radius2xl;
  static const settingsDialogFieldRadius = gap10;
  static const settingsTileIconSize = 32.0;
  static const settingsAppRoutingIcon = gap36;
  static const settingsRoutingGlyph = gap36;

  // Screen frame
  static const settingsScreenPadH = gap16;
  static const settingsScreenPadTop = gap4;
  static const settingsSectionGap = gap20;

  // A group of rows, and the rows in it
  static const settingsGroupLabelPadStart = gap4;
  static const settingsGroupLabelPadBottom = gap8;

  /// Where a divider between two rows starts: clear of the icon tile, so the
  /// line separates the readings rather than cutting the icons in half.
  static const settingsDividerInset = 52.0;
  static const settingsTilePadH = gap12;
  static const settingsTilePadV = gap10;
  static const settingsTileIconGap = gap10;
  static const settingsTileGlyph = 17.0;
  static const settingsTileLabelGap = gap2;
  static const settingsChevronSize = gap20;

  /// How far past the icon tile's top corner a row's mark sits.
  static const settingsTileIconMarkOverhang = gap2;

  /// A row carrying a switch is padded tighter at the switch end: the control
  /// brings its own touch slop, and the default inset put it off the grid.
  static const settingsSwitchPadStart = gap12;
  static const settingsSwitchPadEnd = gap8;
  static const settingsSwitchPadV = gap8;
  static const settingsSwitchChevronInset = gap2;

  // Footer note
  static const settingsFooterPadH = gap12;
  static const settingsFooterPadV = gap10;
  static const settingsFooterGlyph = gap16;
  static const settingsFooterGap = gap8;

  // App-routing row
  static const settingsAppRoutingPadH = gap8;
  static const settingsAppRoutingPadV = gap6;
  static const settingsAppRoutingGap = gap10;
  static const settingsAppRoutingLabelGap = 1.0;
  static const settingsAppRoutingBadgeGap = gap6;

  // Sizes the VPN or Direct tag on an app-routing row.
  static const settingsAppRoutingTagPadH = gap6;
  static const settingsAppRoutingTagPadV = gap2;
  static const settingsAppRoutingTagRadius = radiusSm;

  // Language dropdown. The field is a settings row, so it takes the row's
  // padding, type sizes and chevron; the menu takes the card's corners.
  static const settingsLanguageMenuRadius = settingsTabRadius;
  static const settingsLanguageTick = gap18;

  /// The air between a dropdown's row and the menu it opens, so the menu
  /// floats over the card rather than hanging off its edge.
  static const settingsMenuGap = gap6;

  /// The menu's inset above its first row and below its last, so the chosen
  /// row's tint stops short of the rounded corners.
  static const settingsMenuPadV = gap6;

  /// How far the menu lifts off the page.
  static const settingsMenuElevation = 6.0;

  // --- Settings: first-run language screen ---------------------------------

  // The mark, the insets and the title size are the permission gate's: the
  // two screens follow each other on a first launch and should read as one
  // sequence rather than as two designs.
  static const firstRunLanguageInsetH = notifyGateInsetH;
  static const firstRunLanguageMarkSize = notifyGateMarkSize;
  static const firstRunLanguageMarkGlyph = notifyGateMarkGlyph;
  static const firstRunLanguageMarkToTitle = notifyGateMarkToTitle;
  static const firstRunLanguageTitle = notifyGateTitle;
  static const firstRunLanguageSubtitle = text4xl;
  static const firstRunLanguageTitleGap = gap6;
  static const firstRunLanguageTitleToPicker = notifyGateBodyToAction;
  static const firstRunLanguagePickerToAction = gap16;
  static const firstRunLanguageActionToHint = notifyGateActionGap;
  static const firstRunLanguageHint = notifyGateHint;
  static const firstRunLanguageHintGap = gap4;
  static const firstRunLanguageHintLineHeight = notifyGateHintLineHeight;

  // Routing rules
  static const settingsRoutingRowGap = gap10;
  static const settingsRoutingEmptyPad = gap32;
  static const settingsRoutingActionGlyph = gap18;
  static const settingsRoutingActionGap = gap12;
  static const settingsRoutingBarPadH = gap8;
  static const settingsRoutingBarPadTop = gap12;
  static const settingsRoutingBarPadBottom = gap8;

  // Bypass-LAN tile
  static const settingsBypassPadH = gap12;
  static const settingsBypassPadTop = gap10;
  static const settingsBypassPadBottom = gap12;
  static const settingsBypassRefreshPad = gap4;
  static const settingsBypassRefreshGlyph = gap18;
  static const settingsBypassGap = gap8;
  static const settingsBypassRowPadV = gap6;
  static const settingsBypassDot = gap16;
  static const settingsBypassRowGap = gap6;
  static const settingsBypassCopyPadH = gap12;
  static const settingsBypassCopyPadV = gap10;
  static const settingsBypassCopyGlyph = gap16;

  // Add-rule sheet
  static const settingsSheetPadH = gap20;
  static const settingsSheetPadTop = gap20;
  static const settingsSheetPadBottom = gap24;
  static const settingsSheetGap = gap16;
  static const settingsSheetFieldGap = gap14;

  // DNS dialog
  static const settingsDnsPad = gap16;
  static const settingsDnsFieldGap = gap10;
  static const settingsDnsInvalidGap = gap6;
  static const settingsDnsSuggestGap = gap12;
  static const settingsDnsSuggestTop = gap8;
  static const settingsDnsChipGap = gap6;
  static const settingsDnsActionGap = gap16;
  static const settingsDnsFieldPadH = gap12;
  static const settingsDnsFieldPadV = gap10;
  static const settingsDnsChipPadH = gap10;
  static const settingsDnsChipPadV = gap6;

  // App-routing screen
  static const settingsAppRoutingBarPadStart = gap8;
  static const settingsAppRoutingBarPadTop = gap8;
  static const settingsAppRoutingBarPadEnd = gap12;
  static const settingsAppRoutingBarPadBottom = gap4;
  static const settingsAppRoutingTabPad = gap8;
  static const settingsAppRoutingSectionPadH = gap16;
  static const settingsAppRoutingModesPadTop = gap4;
  static const settingsAppRoutingPickPadTop = gap12;
  static const settingsAppRoutingSearchPadH = gap16;
  static const settingsAppRoutingSearchPadTop = gap8;
  static const settingsAppRoutingSearchPadBottom = gap10;
  static const settingsAppRoutingSearchHeight = gap40;
  static const settingsAppRoutingSearchInset = gap12;
  static const settingsAppRoutingSearchGlyph = gap18;
  static const settingsAppRoutingSearchGap = gap8;
  static const settingsAppRoutingListPadH = gap16;
  static const settingsAppRoutingGroupPadH = gap8;
  static const settingsAppRoutingGroupPadV = gap4;
  static const settingsAppRoutingDividerInset = 46.0;
  static const settingsAppRoutingEmptyPad = gap32;
  static const settingsAppRoutingEmptyGlyph = gap40;
  static const settingsAppRoutingEmptyGap = gap12;

  // Sizes the bar that splits the listed apps between the VPN and direct, and
  // the counts under it.
  static const settingsAppRoutingSummaryPadTop = gap14;
  static const settingsAppRoutingSummaryHeight = gap6;
  static const settingsAppRoutingSummaryRadius = radiusPill;
  static const settingsAppRoutingSummaryGap = gap6;

  // --- App update ----------------------------------------------------------

  /// The dot marking a newer release, on the settings tab and on its row.
  static const updateDot = gap8;

  static const updateDialogInset = gap22;
  static const updateRingSize = gap72;
  static const updateRingBorderWidth = 1.5;
  static const updateCardRadius = radius2xl;
  static const updateTileRadius = radiusLg;
  static const updateIconBoxRadius = gap10;
  static const updateIconBoxSize = gap36;
  static const updateButtonRadius = radiusXl;
  static const updateButtonHeight = gap52;
  static const updateButtonGlyph = gap20;
  static const updateButtonGlyphGap = gap10;

  static const updateDialogPadH = gap24;
  static const updateDialogPadTop = gap28;
  static const updateDialogPadBottom = gap24;
  static const updateHeaderToCard = gap22;
  static const updateCardToButton = 26.0;
  static const updateMarkGlyph = 34.0;
  static const updateMarkToTitle = gap18;
  static const updateTitleToBody = gap10;
  static const updateCardPad = gap16;
  static const updateStepGap = gap10;
  static const updateStepBadgePad = gap6;
  static const updateStepGlyph = gap14;
  static const updateTilePadH = gap12;
  static const updateTilePadV = gap10;
  static const updateTileGlyph = gap18;
  static const updateTileGlyphGap = gap12;
  static const updateTileLabelGap = gap2;

  // --- Notifications (permission gate) -------------------------------------

  static const notifyGateInsetH = gap28;
  static const notifyGateMarkSize = 96.0;
  static const notifyGateMarkGlyph = gap48;
  static const notifyGateMarkToTitle = gap28;
  static const notifyGateTitleToBody = gap16;
  static const notifyGateBodyToAction = gap36;
  static const notifyGateActionGap = gap12;
  static const notifyGateTitle = text6xl;
  static const notifyGateBody = text2xl;
  static const notifyGateHint = textLg;
  static const notifyGateBodyLineHeight = 1.5;
  static const notifyGateHintLineHeight = 1.4;

  // --- Ads (post-connect overlay) ------------------------------------------

  static const adGateHeight = gap44;
  static const adGatePadding = gap4;
  static const adGateBadgeGap = 5.0;
  static const adGateBadgePadding = 13.0;
  static const adGateBadgeGlyph = textXl;
  static const adGateBadgeLabel = gap12;
  static const adGateRailGap = 11.0;
  static const adGateRailHeight = gap6;
  static const adGateRailRadius = gap3;
  static const adGateKnobDigits = 15.0;
  static const adGateKnobGlyph = 22.0;
  static const adBannerStandInHeight = 160.0;
  static const adBannerRadius = radius3xl;
  static const adCardMargin = gap12;
  static const adCardPad = gap20;
  static const adCardRadius = gap24;
  static const adActionRadius = radiusXl;
  static const adActionLift = 0.16;
  static const adContentPadH = gap16;
  static const adBottomPad = gap20;
  static const adSkipIconPad = gap14;
  static const adSkipActionRadius = radiusLg;

  // Gate row frame
  static const adGatePadH = gap12;
  static const adGatePadTop = gap10;
  static const adGatePadBottom = gap6;

  // The skeleton shown while an ad loads
  static const adSkeletonTitleWidth = 160.0;
  static const adSkeletonTitleHeight = gap22;
  static const adSkeletonBodyWidth = 220.0;
  static const adSkeletonTailWidth = 180.0;
  static const adSkeletonLineHeight = gap14;
  static const adSkeletonRadius = gap6;
  static const adSkeletonTitleGap = gap10;
  static const adSkeletonLineGap = gap8;

  // Ad body
  static const adCloseRowPadV = gap8;
  static const adBrokenGlyph = gap48;
  static const adTitleGap = gap8;
  static const adBodyGap = gap16;
  static const adActionPadV = gap14;

  // Skip warning
  static const adSkipGlyph = gap32;
  static const adSkipBodyGap = gap10;
  static const adSkipActionGap = gap24;
  static const adSkipActionGutter = gap10;
  static const adSkipActionPadV = gap12;
  static const adSkipMark = gap18;

  // --- Core widgets --------------------------------------------------------

  static const coreDialogRadius = gap24;

  // --- Core: ink popups ------------------------------------------------------

  static const inkDialogPad = gap24;
  static const inkEmblem = gap52;
  static const inkEmblemRadius = gap16;
  static const inkEmblemGlyph = gap24;
  static const inkDialogEmblemGap = gap18;
  static const inkDialogTitle = text5xl;
  static const inkDialogTitleTracking = -0.2;
  static const inkDialogTitleLineHeight = 1.25;
  static const inkDialogTextGap = gap8;
  static const inkDialogMessage = 13.5;
  static const inkDialogMessageLineHeight = 1.5;
  static const inkDialogSectionGap = gap20;
  static const inkDialogActionsGap = gap24;
  static const inkActionsGap = gap10;
  static const inkButtonHeight = gap48;
  static const inkButtonRadius = radiusXl;
  static const inkButtonPadH = gap16;
  static const inkButtonLabel = textXl;
  static const inkButtonGlyph = gap16;
  static const inkButtonGap = gap8;
  static const inkFieldRadius = radiusXl;
  static const inkFieldPadH = gap16;
  static const inkFieldPadV = gap14;
  static const inkFieldLabel = text2xl;
  static const inkChipGap = gap8;
  static const inkChipRadius = gap10;
  static const inkChipPadH = gap12;
  static const inkChipPadV = gap8;
  static const inkSegmentPad = gap4;
  static const inkSegmentRadius = radiusXl;
  static const inkSegmentThumbRadius = gap10;
  static const inkSegmentHeight = gap40;
  static const inkSegmentGlyph = gap16;
  static const inkSegmentGap = gap6;
  static const inkSegmentLabel = textXl;
  static const coreDialogInsetH = gap24;
  static const coreDialogPad = gap20;
  static const coreToastRadius = radiusXl;
  static const coreToastPadH = gap14;
  static const coreToastPadV = gap12;
  static const coreToastIcon = gap20;
  static const coreToastGap = gap10;
  static const coreToastCloseGap = gap6;
  static const coreToastClearance = 107.0;
  static const coreErrorToastPadH = gap14;
  static const coreErrorToastPadV = gap12;
  static const coreErrorToastIcon = gap20;
  static const coreErrorToastHintGap = gap4;
  static const coreErrorToastHelpGap = gap8;
  static const coreErrorToastClose = 18.0;
}
