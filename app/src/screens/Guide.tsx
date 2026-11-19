// कसरी चलाउने? — the how-to guide for every function, inside the app so it is always the
// same version as the app. Each topic: who it is for, numbered steps, and a button that opens
// the screen it describes. Nepali first; English through the same toggle as the rest of the app.
import { lang } from '../lib/i18n';
import { go } from '../state';
import { source } from '../data/source';
import { Screen } from '../ui';

type L = [string, string];   // [Nepali, English]
interface Topic { id: string; title: L; who?: L; steps: L[]; open?: { route: string; label: L }; tip?: L }
interface Part { title: L; topics: Topic[] }

const T = (l: L) => (lang.value === 'np' ? l[0] : l[1]);

const PARTS: Part[] = [
  {
    title: ['सुरु गर्दा', 'Getting started'],
    topics: [
      {
        id: 'what', title: ['चौतारी के हो?', 'What is चौतारी?'],
        steps: [
          ['वन समूह, सहकारी र गुठीको पैसा, कामको घण्टा, निर्णय र पानी-जङ्गलको हिसाब एकै ठाउँमा।', 'The money, work hours, decisions and water-and-forest records of the forest group, the cooperative and the Guthi, in one place.'],
          ['चौतारीले हिसाब मात्र राख्छ। भुक्तानी, ऋण वा दर्ता आफैं गर्दैन; मान्छेले गर्छन्।', 'चौतारी only keeps the record. It never pays, lends or registers anything; people do.'],
          ['माथि "नमुना तथ्याङ्क" लेखिएको छ भने नाम र अङ्क काल्पनिक हुन्।', 'If "Sample data" shows at the top, the names and figures are made up.'],
        ],
      },
      {
        id: 'lang', title: ['भाषा र मिति', 'Language and dates'],
        steps: [
          ['माथि दायाँ "English" थिच्नुहोस्; फर्कन "नेपाली" थिच्नुहोस्।', 'Tap "English" at the top right; tap "नेपाली" to switch back.'],
          ['सबै मिति विक्रम संवत्‌मा छन्; अङ्क नेपालीमा।', 'All dates are in Bikram Sambat; numbers in Nepali digits when in Nepali.'],
          ['तलका बटनहरू: गृह, मेरो, (पदाधिकारीलाई) काम बाँकी, जाँच, मद्दत।', 'The bottom buttons: Home, Mine, To do (officers only), Check, Help.'],
        ],
      },
      {
        id: 'install', title: ['फोनमा राख्ने', 'Put it on your phone'],
        steps: [
          ['Chrome मा चौतारी खोल्नुहोस्।', 'Open चौतारी in Chrome.'],
          ['माथि दायाँ ⋮ थिचेर "Add to Home screen" (गृह स्क्रिनमा थप्नुहोस्) छान्नुहोस्।', 'Tap ⋮ at the top right and choose "Add to Home screen".'],
          ['अब यो अरू एपजस्तै खुल्छ। इन्टरनेट नहुँदा पछिल्लो पटक हेरेको हिसाब देखाउँछ।', 'It now opens like any app. Without internet it shows the figures you last saw.'],
        ],
        tip: ['यो सुविधा वास्तविक एपमा हुन्छ; नमुना पानामा नहुन सक्छ।', 'This works in the real app; the sample page may not offer it.'],
      },
    ],
  },
  {
    title: ['सबैले हेर्न सकिने (लग इन बिना)', 'What everyone can see (no sign-in)'],
    topics: [
      {
        id: 'home', title: ['गृह: चार टायल', 'Home: the four tiles'],
        steps: [
          ['हाम्रो पैसा: बैंक र हातको नगद जम्मा, यो वर्षको आम्दानी र खर्च।', 'Our money: bank plus cash in hand, this year’s income and spending.'],
          ['हाम्रो काम: पछिल्लो महिना कति घरले पैसा आउने काम पाए।', 'Our work: how many households got paid work last month.'],
          ['हाम्रो पानी र प्रकृति: मूलको पछिल्लो पानी (लिटर प्रति मिनेट) र घट्दै वा बढ्दै।', 'Our water and nature: the latest spring flow (litres a minute) and whether it is falling or rising.'],
          ['हाम्रो निर्णय: खुला प्रश्न र ध्यान दिनुपर्ने कुरा।', 'Our decisions: open questions and what needs attention.'],
          ['कुनै पनि टायल थिच्दा पूरा विवरण खुल्छ। हरियो "अभिलेख अखण्ड छ" थिच्दा जाँच खुल्छ।', 'Tap any tile for the full detail. Tap the green "record is unbroken" line to open the check.'],
        ],
        open: { route: 'home', label: ['गृह खोल्नुहोस्', 'Open Home'] },
      },
      {
        id: 'money', title: ['हाम्रो पैसा', 'Our money'],
        steps: [
          ['माथि बैंकमा र हातमा कति छ। रातो चिन्ह आए नगद सीमा नाघेको वा ७ दिनभित्र बैंकमा नगएको हो।', 'At the top: what is in the bank and in hand. A red tag means cash is over the limit or was not banked within 7 days.'],
          ['आर्थिक वर्षको आम्दानी र खर्च, शीर्षकअनुसार।', 'The fiscal year’s income and spending, by head.'],
          ['बजेट: हरेक बजेट रेखामा कति खर्च भयो, कति बाँकी, र कुन सभाको निर्णयले पास भयो।', 'Budget: how much of each budget line is spent and left, and which assembly decision passed it.'],
          ['खर्चको अनुपात: वन काममा कम्तीमा २५% र बाँकीको आधा विपन्न, महिला र उद्यममा। कालो धर्सा चाहिने रकम हो।', 'Spending shares: at least 25% on forest work and half the rest on poor households, women and enterprise. The dark mark is the amount needed.'],
          ['सबै भुक्तानी: भौचर नम्बर, मिति, शीर्षक र पसलको नाम। व्यक्तिलाई गरेको भुक्तानीमा नाम देखिँदैन।', 'All payments: voucher number, date, head and the shop’s name. Payments to a person never show the name.'],
          ['"अनुमानित" भनेको बिल हराएको; गाउँको मूल्य सूचीको रकम राखिएको।', '"Estimated" means the bill was lost and the village price-list amount was recorded.'],
        ],
        open: { route: 'money', label: ['हाम्रो पैसा खोल्नुहोस्', 'Open Our money'] },
      },
      {
        id: 'work', title: ['हाम्रो काम र पालो', 'Our work and fair turns'],
        steps: [
          ['सबैको एउटै घण्टा ज्याला दर माथि देखिन्छ।', 'The one hourly rate for everyone shows at the top.'],
          ['पालो: हरेक महिना कुन घर नम्बरले कति घण्टा पैसा आउने काम पाए। नाम होइन, घर नम्बर मात्र।', 'Fair turns: paid hours each month by house number. House numbers only, never names.'],
          ['सुन्तला "पैसा आउने काम पाएनन्" भनेको त्यो घरले पालो पाएन; "अस्वीकार" भनेको प्रस्ताव आयो तर लिएनन्।', 'Orange "no paid work" means that household got no turn; "declined" means work was offered but not taken.'],
          ['योजनामा काम: हरेक योजनामा कति घण्टा र कति जना। ५ जनाभन्दा कम भए गोपनीयताका लागि लुकाइन्छ।', 'Work by project: hours and people on each project. Fewer than 5 people are hidden for privacy.'],
        ],
        open: { route: 'work', label: ['हाम्रो काम खोल्नुहोस्', 'Open Our work'] },
      },
      {
        id: 'nature', title: ['हाम्रो पानी र प्रकृति', 'Our water and nature'],
        steps: [
          ['हरेक मूलको चित्र: हरेक दुई हप्तामा बाल्टिन र घडीले नापिएको पानी।', 'A chart for each spring: water measured every two weeks with a bucket and a watch.'],
          ['गोलो घेरा पछिल्लो नाप हो। "घट्दै" भनेको पहिलो नापभन्दा १०% वा बढी कम।', 'The circled point is the latest reading. "Falling" means 10% or more below the first reading.'],
          ['तल वर्षा, मिलिमिटरमा।', 'Below: rainfall in millimetres.'],
        ],
        open: { route: 'nature', label: ['पानी र प्रकृति खोल्नुहोस्', 'Open Water and nature'] },
      },
      {
        id: 'decisions', title: ['हाम्रो निर्णय', 'Our decisions'],
        steps: [
          ['ध्यान दिनुपर्ने: नियमको सीमा नाघेका कुरा (जस्तै मूल सुक्दै, विपन्नमा खर्च कम)। एपले देखाउँछ; निर्णय भेलाले गर्छ।', 'Needs attention: where a rule’s threshold is crossed (a spring drying, too little spent on poor households). The app shows; the assembly decides.'],
          ['प्रश्न र जवाफ: सदस्यले सोधेका प्रश्न, र लेखा समितिको जवाफ चार नतिजामध्ये एक: स्पष्ट पारियो, फरक रकम फिर्ता, रकम फिर्ता, तरिका सुधारियो।', 'Questions and answers: members’ questions and the accounts committee’s answer, with one of four outcomes: explained, difference returned, refunded, process improved.'],
          ['पदाधिकारी: अहिले को कुन पदमा छन्।', 'Office holders: who holds which office now.'],
          ['नियमहरू: हरेक नियम, किन छ, र कुन विधान वा निर्णयबाट आयो।', 'Rules: every rule, why it exists, and which constitution section or decision it comes from.'],
        ],
        open: { route: 'decisions', label: ['हाम्रो निर्णय खोल्नुहोस्', 'Open Our decisions'] },
      },
      {
        id: 'coop', title: ['सहकारी (दर्ता अघि नमुना)', 'The cooperative (sample until registered)'],
        steps: [
          ['गृहको तल सहकारीको नाम थिच्नुहोस्।', 'Tap the cooperative’s name at the bottom of Home.'],
          ['सदस्य, शेयर पूँजी (हरेकको रु १०० को एक कित्ता), बैंक, परियोजना ऋण र बाँकी अनुदान।', 'Members, share capital (one share of Rs 100 each), bank, project loans and unspent grants.'],
          ['उद्यम: आम्दानी, खर्च, काम घण्टा र प्रति घण्टा कमाइ, समान ज्याला दरसँग तुलना।', 'Enterprises: income, spending, hours worked and earnings per hour, next to the equal wage rate.'],
          ['परियोजना ऋण दर्ता: सबैलाई एउटै ब्याजदर। सदस्यको नाम गोप्य। सूचना दिइएको भए फिर्ता पाउने मिति देखिन्छ।', 'Project loan register: one rate for everyone. Members’ names stay private. Where notice was given, the repayment date shows.'],
          ['अनुदान: कुन कामका लागि, कति खर्च, कति बाँकी।', 'Grants: what each is for, how much is spent and left.'],
          ['वर्षान्तको बाँडफाँड: जगेडा कोष पहिले, त्यसपछि ४०% समुदाय, ३०% संरक्षित पूँजी फिर्ता कोष, ३०% पूँजी, प्रविधि र तालिम।', 'Year-end split: reserve funds first, then 40% community, 30% protected capital return fund, 30% capital, technology and training.'],
        ],
        open: { route: 'coop', label: ['सहकारी खोल्नुहोस्', 'Open the cooperative'] },
      },
      {
        id: 'check', title: ['जाँच: अभिलेख कसैले बदलेको छैन', 'Check: nobody changed the record'],
        steps: [
          ['तल "जाँच" थिच्नुहोस्। फोनले आफैं सबै इन्ट्रीको औंठाछाप मिलाउँछ।', 'Tap "Check" at the bottom. Your phone checks every entry’s fingerprint itself.'],
          ['हरियो "अभिलेख अखण्ड छ" भनेको कुनै पुरानो अङ्क बदलिएको छैन।', 'Green "the record is unbroken" means no old figure has been changed.'],
          ['"एउटा अङ्क बदलेर हेर्नुहोस्" थिच्दा तपाईंको फोनको प्रतिलिपिमा मात्र एउटा रकम बदलिन्छ, र रातो देखिन्छ। "सक्कल फर्काउनुहोस्" थिचेर फर्काउनुहोस्।', '"Try changing one figure" changes one amount in your phone’s copy only, and the check turns red. Tap "Restore the original" to undo.'],
          ['कम्प्युटरमा पनि जाँच्न सकिन्छ: तल दिइएको आदेश चलाउनुहोस्।', 'You can also check on a computer with the command shown at the bottom.'],
        ],
        open: { route: 'check', label: ['जाँच खोल्नुहोस्', 'Open Check'] },
      },
    ],
  },
  {
    title: ['सदस्यले गर्ने', 'For members'],
    topics: [
      {
        id: 'signin', title: ['भित्र जाने', 'Sign in'],
        steps: [
          ['तल "मेरो" थिच्नुहोस्।', 'Tap "Mine" at the bottom.'],
          ['आफ्नो मोबाइल नम्बर लेखेर "कोड पठाउनुहोस्" थिच्नुहोस्।', 'Enter your mobile number and tap "Send code".'],
          ['SMS मा आएको कोड लेखेर "पुष्टि गर्नुहोस्" थिच्नुहोस्।', 'Enter the code from the SMS and tap "Confirm".'],
        ],
        tip: ['नमुनामा कोड चाहिँदैन: नामको सूचीबाट कुनै व्यक्ति छान्नुहोस्। बाहिर निस्कन "बाहिर निस्कनुहोस्"।', 'In the sample no code is needed: pick a person from the list. To leave, tap "Sign out".'],
        open: { route: 'mine', label: ['मेरो खोल्नुहोस्', 'Open Mine'] },
      },
      {
        id: 'myrecord', title: ['वन समूहको मेरो अभिलेख', 'My forest-group record'],
        steps: [
          ['"वन समूहको अभिलेख" ट्याबमा: मेरो काम, कुन मितिमा कति घण्टा। "स्वीकृति पर्खँदै" भनेको सुपरिवेक्षकले अझै हेरेका छैनन्।', 'In the "Forest group record" tab: my work, hours by date. "Waiting for approval" means the supervisor has not checked it yet.'],
          ['मलाई भएको भुक्तानी, मेरो घरको पालो, र पर्म: कुन घरलाई कति दिन दिइयो र पाइयो।', 'Payments to me, my household’s turns, and parma: days given to and received from each household.'],
          ['मेरा प्रश्न र तिनको नतिजा।', 'My questions and their outcomes.'],
        ],
        tip: ['अरू कसैको अभिलेख कसैले देख्दैन; यो नियम डाटाबेसमै छ।', 'Nobody can see anyone else’s record; the rule is in the database itself.'],
      },
      {
        id: 'account', title: ['मेरो खाता (सहकारी)', 'My account (cooperative)'],
        steps: [
          ['"मेरो खाता" ट्याब थिच्नुहोस्। माथि हरियो बाकसमा सहकारीमा मेरो पैसा: शेयर + परियोजना ऋण + पाउन बाँकी ज्याला र लाभ।', 'Tap the "My account" tab. The green box shows my money in the cooperative: share + project loan + wages and benefit due.'],
          ['मेरो परियोजना ऋण: रकम, ब्याजदर, र रु १ लाखसम्म भए "सूचनामा फिर्ता", बढी भए अवधि सकिने मिति।', 'My project loan: amount, rate, and "withdrawable on notice" (up to Rs 1 lakh) or the date the fixed term ends.'],
          ['यो वर्षको संरक्षित पूँजी फिर्ता (अनुमान) र सक्रिय सदस्य हुन चाहिने घण्टा कति पुग्यो।', 'This year’s protected capital return (estimate) and how far I am towards the hours an active member needs.'],
          ['विवरण: हरेक कारोबार, मिति र भौचर नम्बरसहित, बैंकको पासबुकजस्तै।', 'Statement: every transaction with its date and voucher number, like a bank passbook.'],
        ],
      },
      {
        id: 'notice', title: ['परियोजना ऋण फिर्ता माग्ने सूचना', 'Give notice to withdraw a project loan'],
        who: ['रु १ लाखसम्मको परियोजना ऋण भएका सदस्य', 'Members with a project loan up to Rs 1 lakh'],
        steps: [
          ['मेरो › मेरो खाता › मेरो परियोजना ऋणमा "फिर्ता माग्ने सूचना दिनुहोस्" थिच्नुहोस्।', 'Mine › My account › My project loan: tap "Give notice to withdraw".'],
          ['कति फिर्ता चाहिन्छ लेख्नुहोस् (बाँकी रकमभन्दा बढी हुँदैन)।', 'Enter how much you want back (no more than what is outstanding).'],
          ['"फिर्ता माग्ने सूचना दिनुहोस्" थिच्नुहोस्। सूचना दिएको मिति र ३ महिनापछि फिर्ता पाउने मिति देखिन्छ।', 'Tap "Give notice to withdraw". The notice date and the repayment date, 3 months later, appear.'],
          ['रकम ब्याजसहित फिर्ता हुन्छ। सूचना सहकारीको दर्तामा पनि देखिन्छ, तपाईंको नाम बिना।', 'The money comes back with interest. The notice also shows on the cooperative’s register, without your name.'],
        ],
        tip: ['नमुनामा "दिल" छान्नुहोस्; टेकले सूचना दिइसक्नुभएको छ। रु १ लाखभन्दा बढीको ऋण ३–५ वर्षको तोकिएको अवधिको हुन्छ, सूचनाबाट फिर्ता हुँदैन।', 'In the sample pick "दिल"; Tek has already given notice. Loans above Rs 1 lakh run a fixed 3–5 years and are not withdrawn on notice.'],
        open: { route: 'mine', label: ['मेरो खोल्नुहोस्', 'Open Mine'] },
      },
      {
        id: 'ask', title: ['खर्चबारे प्रश्न सोध्ने', 'Ask about a payment'],
        steps: [
          ['पहिले भित्र जानुहोस्, अनि हाम्रो पैसामा "सबै भुक्तानी" मा जानुहोस्।', 'Sign in first, then go to Our money › All payments.'],
          ['जुन भुक्तानीबारे बुझ्न चाहनुहुन्छ, त्यसमुनि "प्रश्न सोध्नुहोस्" थिच्नुहोस्।', 'Under the payment you want to know about, tap "Ask about this".'],
          ['प्रश्न लेखेर "पठाउनुहोस्" थिच्नुहोस्।', 'Write your question and tap "Send".'],
          ['प्रश्न लेखा समितिमा जान्छ, खर्च गर्ने व्यक्तिलाई होइन। तपाईंको नाम लेखा समितिले मात्र देख्छ। जवाफ हाम्रो निर्णयमा सबैले देख्छन्।', 'The question goes to the accounts committee, not to the person who spent the money. Only the committee sees your name. Everyone sees the answer under Our decisions.'],
        ],
        tip: ['सोध्नु शंका होइन; धन्यवादको काम हो।', 'Asking is not an accusation; it is a service to everyone.'],
        open: { route: 'money', label: ['हाम्रो पैसा खोल्नुहोस्', 'Open Our money'] },
      },
    ],
  },
  {
    title: ['पदाधिकारीले गर्ने', 'For officers'],
    topics: [
      {
        id: 'todo', title: ['काम बाँकी', 'To do'],
        who: ['कोषाध्यक्ष, अध्यक्ष, सचिव, सुपरिवेक्षक, लेखा समिति', 'Treasurer, chair, secretary, supervisor, accounts committee'],
        steps: [
          ['पदमा हुनुहुन्छ भने तल "काम बाँकी" बटन देखिन्छ। त्यहाँ तपाईंको पदअनुसारका काम मात्र आउँछन्।', 'If you hold an office, a "To do" button appears at the bottom, with only the tasks your office allows.'],
        ],
        tip: ['नमुनामा: हरि (कोषाध्यक्ष), सीता (सचिव), राम (अध्यक्ष), विकास (सुपरिवेक्षक), कमला (लेखा समिति)।', 'In the sample: हरि (treasurer), सीता (secretary), राम (chair), विकास (supervisor), कमला (accounts committee).'],
      },
      {
        id: 'sign', title: ['भुक्तानीमा हस्ताक्षर र भुक्तानी', 'Sign and release a payment'],
        who: ['वन समूहमा: कोषाध्यक्ष र अध्यक्ष वा सचिव', 'In the forest group: the treasurer and the chair or secretary'],
        steps: [
          ['काम बाँकीमा भुक्तानी, रकम, पसल र बजेट रेखा हेर्नुहोस्। कसले हस्ताक्षर गरिसके भन्ने पनि देखिन्छ।', 'In To do, check the payment, amount, shop and budget line. It also shows who has signed already.'],
          ['"हस्ताक्षर गर्नुहोस्" थिच्नुहोस्। तपाईंको पदको नाममा हस्ताक्षर हुन्छ।', 'Tap "Sign". You sign in the name of your office.'],
          ['कोषाध्यक्ष र अध्यक्ष वा सचिव दुवैले हस्ताक्षर गरेपछि "भुक्तानी दिनुहोस्" देखिन्छ; त्यसपछि भुक्तानी हिसाबमा चढ्छ।', 'Once the treasurer and the chair or secretary have both signed, "Release payment" appears; then the payment enters the books.'],
        ],
        tip: ['दुई फरक व्यक्ति र एक जना महिला चाहिन्छ। खर्च लेख्ने व्यक्ति र आफ्नै घरलाई भुक्तानीमा हस्ताक्षर गर्न मिल्दैन। डाटाबेसले रोक्छ।', 'It takes two different people, one of them a woman. Whoever recorded the expense, or whose household is being paid, cannot sign. The database stops it.'],
        open: { route: 'tasks', label: ['काम बाँकी खोल्नुहोस्', 'Open To do'] },
      },
      {
        id: 'approve', title: ['कामको घण्टा स्वीकृत गर्ने', 'Approve work hours'],
        who: ['सुपरिवेक्षक', 'Supervisor'],
        steps: [
          ['काम बाँकीमा कसले, कुन घरबाट, कुन मिति, कति घण्टा काम गरे हेर्नुहोस्।', 'In To do, check who worked, from which house, on which date and for how many hours.'],
          ['ठीक भए "स्वीकृत गर्नुहोस्" थिच्नुहोस्। स्वीकृत भएपछि मात्र ज्याला दिन मिल्छ।', 'If it is right, tap "Approve". Wages can be paid only after approval.'],
        ],
        tip: ['आफ्नो वा आफ्नो घरको काम अर्को सुपरिवेक्षकले स्वीकृत गर्छन्।', 'Your own or your household’s hours are approved by another supervisor.'],
        open: { route: 'tasks', label: ['काम बाँकी खोल्नुहोस्', 'Open To do'] },
      },
      {
        id: 'answer', title: ['प्रश्नको जवाफ दिने', 'Answer a question'],
        who: ['लेखा समिति', 'Accounts committee'],
        steps: [
          ['काम बाँकीमा प्रश्न, कुन इन्ट्रीबारे, र कसले सोधे देखिन्छ (नाम तपाईंले मात्र देख्नुहुन्छ)।', 'In To do you see the question, which entry it is about, and who asked (only you see the name).'],
          ['नतिजा छान्नुहोस्: स्पष्ट पारियो, फरक रकम फिर्ता, रकम फिर्ता, वा तरिका सुधारियो।', 'Choose the outcome: explained, difference returned, refunded, or process improved.'],
          ['जवाफ लेखेर "जवाफ दिनुहोस्" थिच्नुहोस्। जवाफ सबैले देख्छन्; सोध्नेको नाम देखिँदैन।', 'Write the answer and tap "Answer". Everyone sees the answer; the asker’s name stays private.'],
        ],
        open: { route: 'tasks', label: ['काम बाँकी खोल्नुहोस्', 'Open To do'] },
      },
    ],
  },
  {
    title: ['सुरक्षा र नियम', 'Safety and rules'],
    topics: [
      {
        id: 'nobody', title: ['कसैले गर्न नसक्ने कुरा', 'What nobody can do'],
        steps: [
          ['पुरानो इन्ट्री बदल्न वा मेटाउन, पदाधिकारी वा एप बनाउनेले पनि।', 'Change or delete an old entry, not even an officer or the app’s makers.'],
          ['दुई जनाको हस्ताक्षर बिना भुक्तानी दिन, वा बजेट रेखाभन्दा बढी खर्च गर्न।', 'Release a payment without two signatures, or spend beyond the budget line.'],
          ['रु १०,००० भन्दा बढी नगदमा लिन; त्यो बैंकबाट आउनुपर्छ।', 'Take more than Rs 10,000 in cash; that has to come through the bank.'],
          ['अरूको व्यक्तिगत अभिलेख हेर्न।', 'Look at another person’s own record.'],
        ],
      },
      {
        id: 'mistake', title: ['गल्ती भए के हुन्छ?', 'What if there is a mistake?'],
        steps: [
          ['गल्ती सच्याउन नयाँ "सच्याइएको" इन्ट्री थपिन्छ, कारणसहित।', 'A new correction entry is added, with the reason.'],
          ['पुरानो इन्ट्री पनि देखिइरहन्छ, त्यसैले के सच्याइयो सबैलाई थाहा हुन्छ।', 'The old entry stays visible, so everyone knows what was corrected.'],
        ],
      },
      {
        id: 'privacy', title: ['कसले के देख्छ?', 'Who sees what?'],
        steps: [
          ['सबैले: कुल रकम, योजना, पानी, बजेट, पसलको नाम, घरअनुसार पालो।', 'Everyone: totals, projects, water, budgets, shop names, turns by house number.'],
          ['तपाईं आफैं: आफ्नो घण्टा, भुक्तानी, शेयर, परियोजना ऋण र पर्म।', 'You alone: your own hours, payments, share, project loan and parma.'],
          ['पदाधिकारी: पदमा रहुन्जेल आफ्नो कामका लागि चाहिने विवरण मात्र।', 'Officers: only the detail their office needs, while they hold it.'],
          ['परिचयपत्र: तपाईं र तोकिएका पदाधिकारी मात्र।', 'Identity documents: you and named officers only.'],
        ],
      },
      {
        id: 'ai', title: ['बिल पढ्ने एआई', 'The AI that reads bills'],
        steps: [
          ['बिलको फोटो खिचेपछि एपले रकम, मिति र पसल पढेर भर्न सुझाव दिन्छ।', 'After a bill is photographed, the app reads the amount, date and shop and suggests the entry.'],
          ['हिसाब राख्ने व्यक्तिले फोटोसँग मिलाएर पुष्टि गरेपछि मात्र हिसाबमा चढ्छ।', 'It enters the books only after the record keeper checks it against the photo and confirms.'],
          ['एआईले हस्ताक्षर, स्वीकृति वा कुनै इन्ट्री बदल्न सक्दैन। यो हाम्रै सर्भरमा चल्छ।', 'The AI cannot sign, approve or change any entry. It runs on our own server.'],
        ],
        tip: ['यो सुविधा बन्दैछ; नमुनामा छैन।', 'This is being built; it is not in the sample yet.'],
      },
    ],
  },
  {
    title: ['प्रायः सोधिने प्रश्न', 'Common questions'],
    topics: [
      {
        id: 'nophone', title: ['स्मार्टफोन छैन भने?', 'No smartphone?'],
        steps: [['सूचना पाटीमा छापिएको मासिक हिसाब र सघाउने व्यक्ति राख्ने प्रस्ताव छ; भेलाले तय गर्छ।', 'The proposal is a printed monthly account on the notice board and a helper; the assembly decides.']],
      },
      {
        id: 'offline', title: ['इन्टरनेट नहुँदा?', 'No internet?'],
        steps: [['एपले पछिल्लो पटक भरिएको हिसाब देखाउँछ र माथि "इन्टरनेट छैन" लेख्छ। जङ्गलमा भरेका फाराम सिग्नल आएपछि पठाइन्छन्।', 'The app shows the last saved figures and says "Offline" at the top. Forms filled in the forest are sent when there is signal.']],
      },
      {
        id: 'sample', title: ['यी नाम र अङ्क साँचो हुन्?', 'Are these names and figures real?'],
        steps: [['होइनन्। नमुनाका सबै नाम र अङ्क काल्पनिक हुन्। भेलाले स्वीकृत गरे मात्र वास्तविक हिसाब राखिन्छ।', 'No. Every name and figure in the sample is made up. Real records start only if the assembly approves.']],
      },
    ],
  },
];

export function Guide() {
  const np = lang.value === 'np';
  return (
    <Screen title={np ? 'कसरी चलाउने?' : 'How to use चौतारी'} back={false}>
      <p class="lede">{np
        ? 'चौतारीका सबै काम, एक एक चरणमा। शीर्षक थिच्दा चरण खुल्छन्; तलको बटनले त्यही पाना खोल्छ।'
        : 'Every function of चौतारी, step by step. Tap a title to open its steps; the button below them opens that screen.'}</p>
      {source.mode === 'sample' && <p class="banner">{np
        ? 'यो नमुना हो: बटन थिच्दा वास्तविक हिसाबमा केही बदलिँदैन, कुन इन्ट्री थपिन्थ्यो भन्ने मात्र देखिन्छ।'
        : 'This is the sample: buttons change nothing real; they show the entry that would be added.'}</p>}
      <nav class="guide-index" aria-label={np ? 'विषयसूची' : 'Contents'}>
        {PARTS.map((p, i) => <a key={i} href={`#help`} onClick={(e) => { e.preventDefault(); document.getElementById(`part-${i}`)?.scrollIntoView({ behavior: 'smooth' }); }}>{T(p.title)}</a>)}
      </nav>
      {PARTS.map((p, i) => (
        <section class="section" id={`part-${i}`} key={i}>
          <h2>{T(p.title)}</h2>
          {p.topics.map((tp) => (
            <details class="guide" key={tp.id} id={`g-${tp.id}`}>
              <summary>{T(tp.title)}</summary>
              {tp.who && <p class="item-meta">{np ? 'कसका लागि: ' : 'For: '}{T(tp.who)}</p>}
              <ol class="guide-steps">{tp.steps.map((s, k) => <li key={k}>{T(s)}</li>)}</ol>
              {tp.tip && <p class="guide-tip">{T(tp.tip)}</p>}
              {tp.open && <button class="btn btn-quiet" onClick={() => go(tp.open!.route)}>{T(tp.open.label)} →</button>}
            </details>
          ))}
        </section>
      ))}
    </Screen>
  );
}
