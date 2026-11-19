// कसरी चलाउने? — the how-to guide for every function, inside the app so it is always the
// same version as the app. Each topic: who it is for, numbered steps, and a button that opens
// the screen it describes. Nepali first; English through the same toggle as the rest of the app.
import { lang } from '../lib/i18n';
import { go } from '../state';
import { source } from '../data/source';
import { Screen } from '../ui';
import { bsDate, digits } from '../lib/format';

// The rules the app currently follows. Change this line in the same pull request as any new bylaws version.
const BYLAWS: L = ['सहकारी विनियम ४.१५ (मस्यौदा)', 'Cooperative bylaws v4.15 (draft)'];

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
        id: 'rules', title: ['यी नियम अन्तिम हुन्?', 'Are these the final rules?'],
        steps: [
          ['अहिले सहकारीका नियम विनियम ४.१५ को मस्यौदा हुन्। भेलाले स्वीकृत गरेपछि मात्र ती लागू हुन्छन्।', 'The cooperative’s rules are for now the draft bylaws v4.15. They apply only once the assembly approves them.'],
          ['सदस्यको परियोजना ऋण वकिलले हेरेपछि मात्र सुरु हुन्छ।', 'Members’ project loans start only after a lawyer has reviewed them.'],
          ['भेलाले केही कुरा (जस्तै पालो सार्वजनिक वा निजी, खर्चको सीमा) अझै तय गर्नुपर्छ। तय भएपछि नियम र यो मद्दत पाना सँगै बदलिन्छन्।', 'The assembly still has to settle a few things (for example whether turns are public or private, and the spending limit). When it does, the rules and this guide change together.'],
        ],
        tip: ['हरेक नियम कुन विधान वा निर्णयबाट आयो, हाम्रो निर्णय › नियमहरूमा देखिन्छ।', 'Every rule and the section or decision it comes from is under Our decisions › Rules.'],
        open: { route: 'decisions', label: ['हाम्रो निर्णय खोल्नुहोस्', 'Open Our decisions'] },
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
        tip: ['नमुना पनि यसरी राख्न सकिन्छ, यसको वेब ठेगानाबाट खोल्दा (claude.ai भित्रबाट वा WhatsApp फाइलबाट होइन)। एक पटक इन्टरनेटमा खोलेपछि बिना इन्टरनेट पनि खुल्छ, र इन्टरनेट आउँदा आफैं अद्यावधिक हुन्छ।', 'The sample can be installed this way too, when opened from its web address (not from inside claude.ai or the WhatsApp file). After opening it once with internet it works without internet, and updates itself when there is signal.'],
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
        id: 'lostphone', title: ['फोन हरायो वा नम्बर फेरियो', 'Lost phone or new number'],
        steps: [
          ['पैसा वा हस्ताक्षर गर्ने शक्ति फोनमा हुँदैन। अर्को फोनबाट आफ्नै नम्बरमा कोड मगाएर भित्र जान सकिन्छ।', 'Nothing in your phone holds money or the power to sign. On another phone you can sign in with a code sent to your own number.'],
          ['नम्बरै फेरिएको भए हिसाब राख्ने पदाधिकारीलाई भन्नुहोस्।', 'If the number itself has changed, tell the record keeper.'],
          ['पदाधिकारीले पद छाडेपछि उनको पहुँच बन्द हुन्छ; उनले गरेका इन्ट्री अभिलेखमै रहिरहन्छन्।', 'When an officer leaves office their access ends; the entries they made stay in the record.'],
        ],
        tip: ['नयाँ नम्बर थप्ने तरिका भेलाले तय गर्नुपर्छ; तय भएपछि यहाँ अद्यावधिक हुन्छ।', 'How a new number is added is for the assembly to settle; this page will be updated when it does.'],
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
      {
        id: 'unanswered', title: ['प्रश्नको जवाफ आएन भने', 'If a question gets no answer'],
        steps: [
          ['पहिले हाम्रो निर्णय › प्रश्न र जवाफ हेर्नुहोस्; जवाफ त्यहीँ आउँछ।', 'First look under Our decisions › Questions and answers; the answer appears there.'],
          ['जवाफ ढिलो भए लेखा समितिका कुनै सदस्यलाई सोध्नुहोस्, वा भेलामा आफैं उठाउनुहोस्। भेलाले नै अन्तिम निर्णय गर्छ।', 'If the answer is slow, ask any member of the accounts committee, or raise it yourself at the assembly. The assembly has the last word.'],
          ['तपाईंको प्रश्न र जवाफ दुवै अभिलेखमा बस्छन्; पछि कसैले मेटाउन सक्दैन।', 'Your question and the answer both stay in the record; nobody can delete them later.'],
        ],
        tip: ['जवाफ दिनुपर्ने समयसीमा भेलाले तय गर्ने कुरा हो; तय भएपछि यहाँ लेखिनेछ।', 'The time limit for an answer is for the assembly to set; it will be written here once set.'],
        open: { route: 'decisions', label: ['हाम्रो निर्णय खोल्नुहोस्', 'Open Our decisions'] },
      },
      {
        id: 'mydata', title: ['मेरो विवरण र सदस्यता छाड्दा', 'My data, and leaving'],
        steps: [
          ['मेरो › मेरो खातामा आफ्नो सबै विवरण देख्न सकिन्छ। स्मार्टफोन नभए सहयोगी वा हिसाब राख्ने पदाधिकारीले छापेर दिन सक्छन्।', 'Mine › My account shows all your own records. If you have no smartphone, a helper or the record keeper can print them for you.'],
          ['तपाईंको परिचयपत्र तपाईं र तोकिएका पदाधिकारीले मात्र देख्छन्; सबैले देख्ने ठाउँमा तपाईंको नाम आउँदैन।', 'Your identity documents are seen only by you and named officers; your name does not appear where everyone can see.'],
          ['पुरानो अभिलेख कसैले मेटाउन सक्दैन, त्यसैले सदस्यता छाडे पनि अघिका कारोबार कुल अङ्कमा रहन्छन्।', 'Old entries cannot be deleted, so if you leave, past transactions stay in the totals.'],
        ],
        tip: ['सदस्यता छाड्दा शेयर कसरी फिर्ता हुन्छ र व्यक्तिगत विवरण कति समय राखिन्छ भन्ने कुरा वकिलको समीक्षापछि यहाँ लेखिनेछ।', 'How a share is returned on leaving, and how long personal details are kept, will be written here after the lawyer’s review.'],
      },
    ],
  },
  {
    title: ['पदाधिकारीले गर्ने', 'For officers'],
    topics: [
      {
        id: 'todo', title: ['काम बाँकी', 'To do'],
        who: ['कोषाध्यक्ष, अध्यक्ष, सचिव, सुपरिवेक्षक, लेखा समिति, लेखापाल, प्रकृति हेरालु', 'Treasurer, chair, secretary, supervisor, accounts committee, ledger keeper, nature guardian'],
        steps: [
          ['पदमा हुनुहुन्छ भने तल "काम बाँकी" बटन देखिन्छ। त्यहाँ तपाईंको पदअनुसारका काम मात्र आउँछन्।', 'If you hold an office, a "To do" button appears at the bottom, with only the tasks your office allows.'],
        ],
        tip: ['नमुनामा: हरि (कोषाध्यक्ष), सीता (सचिव), राम (अध्यक्ष), विकास (सुपरिवेक्षक), कमला (लेखा समिति), गीता (लेखापाल), सरिता (प्रकृति हेरालु)।', 'In the sample: हरि (treasurer), सीता (secretary), राम (chair), विकास (supervisor), कमला (accounts committee), गीता (ledger keeper), सरिता (nature guardian).'],
      },
      {
        id: 'billphoto', title: ['बिलको फोटोबाट खर्च लेख्ने', 'Record spending from a bill’s photo'],
        who: ['कोषाध्यक्ष वा लेखापाल', 'Treasurer or ledger keeper'],
        steps: [
          ['काम बाँकीमा "बिलको फोटोबाट हिसाब" थिच्नुहोस्।', 'In To do, tap "From a bill’s photo".'],
          ['पूरा बिल देखिने गरी, उज्यालोमा, सिधा माथिबाट फोटो खिच्नुहोस्। एआईले रकम, मिति, बिल नं. र पसल पढ्छ।', 'Photograph the whole bill, in good light, straight from above. The AI reads the amount, date, bill number and shop.'],
          ['✓ भएको अङ्क दुई पटक पढ्दा मिल्यो र बिलको आफ्नै जोड (उप-जम्मा + कर = जम्मा) मिल्यो। ! भएको अङ्क फोटो हेरेर आफैं ठीक गर्नुहोस्।', 'A figure with ✓ agreed in two readings and fits the bill’s own sums (sub-total + VAT = total). A figure with ! you put right yourself from the photo.'],
          ['दर्ता भएको पसल र बजेट रेखा छान्नुहोस्, "फोटोसँग मिलाएँ" मा चिनो लगाउनुहोस्, र "मेरो नाममा पुष्टि गर्छु" थिच्नुहोस्।', 'Choose the registered shop and the budget line, tick "I compared it with the photo", and tap "Confirm in my name".'],
          ['खर्च "हस्ताक्षर पर्खँदै" मा जान्छ। कोषाध्यक्ष र अध्यक्ष वा सचिवको हस्ताक्षरपछि मात्र भुक्तानी हुन्छ।', 'The expense goes to "waiting for signatures". It is paid only after the treasurer and the chair or secretary sign.'],
          ['दोहोरिएको, अर्कैको वा पढ्नै नसकिने बिल भए "यो बिल नलिने" थिचेर कारण छान्नुहोस्।', 'If the bill is a duplicate, not ours or unreadable, tap "Do not take this bill" and choose why.'],
        ],
        tip: ['नमुनामा: "मेरो" मा गीता (लेखापाल) छान्नुहोस्, अनि तीनवटा काल्पनिक बिलमध्ये एउटा छान्नुहोस्। तिनमा एआईले साँच्चै पढेको नतिजा देखिन्छ, गल्तीसमेत।', 'In the sample: choose गीता (ledger keeper) under Mine, then one of the three fictional bills. They show what the AI really read, mistakes included.'],
        open: { route: 'capture', label: ['बिलको फोटोबाट हिसाब खोल्नुहोस्', 'Open From a bill’s photo'] },
      },
      {
        id: 'readings', title: ['मूलको पानी र वर्षा नाप्ने', 'Record spring flow and rain'],
        who: ['प्रकृति हेरालु वा लेखापाल', 'Nature guardian or ledger keeper'],
        steps: [
          ['काम बाँकीमा "पानी र वर्षा नाप" थिच्नुहोस्।', 'In To do, tap "Water and rain readings".'],
          ['मूलको पानी: १० लिटरको बाल्टी भरिन कति सेकेन्ड लाग्यो नाप्नुहोस्। ६०० लाई सेकेन्डले भाग गर्दा लिटर प्रति मिनेट आउँछ।', 'Spring flow: time how many seconds a 10-litre bucket takes to fill. 600 divided by the seconds gives litres per minute.'],
          ['वर्षा: मापकमा जम्मा भएको मिलिमिटर लेख्नुहोस्।', 'Rain: write the millimetres in the gauge.'],
          ['मूल वा मापक र मिति छानेर "मेरो नाममा लेख्नुहोस्" थिच्नुहोस्। नाप हाम्रो पानी र प्रकृतिको चार्टमा देखिन्छ।', 'Choose the spring or gauge and the date, and tap "Record in my name". The reading shows on the Our water and nature charts.'],
        ],
        open: { route: 'readings', label: ['पानी र वर्षा नाप खोल्नुहोस्', 'Open Water and rain readings'] },
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
        id: 'worklog', title: ['कामको घण्टा लेख्ने', 'Record work hours'],
        who: ['लेखापाल वा सुपरिवेक्षक', 'Ledger keeper or supervisor'],
        steps: [
          ['काम बाँकीमा "काम र घण्टा लेख्ने" थिच्नुहोस्।', 'In To do, tap "Record work hours".'],
          ['काम गर्ने व्यक्ति नाम वा घर नम्बरले खोजेर छान्नुहोस्।', 'Find the worker by name or house number and choose them.'],
          ['परियोजना, काम र मिति छान्नुहोस्; कति घण्टा, र ज्याला पाउने वा स्वयंसेवा हो छान्नुहोस्। एक जनाको एक दिनमा १२ घण्टाभन्दा बढी लेखिँदैन।', 'Choose the project, the task and the date; then the hours, and whether it is paid or voluntary. No more than 12 hours a person a day can be recorded.'],
          ['काम सुरु हुनुअघि र सकिएपछि उही ठाउँबाट एक-एक फोटो खिच्नुहोस्। फोटो हाम्रै सर्भरमा बस्छ; अभिलेखमा त्यसको औँठाछाप मात्र जान्छ।', 'Take one photo from the same spot before the work starts and one after it ends. The photos stay on our own server; the record carries only their fingerprint.'],
          ['"मेरो नाममा लेख्नुहोस्" थिच्नुहोस्। धेरै जनाले उही काम गरेका भए "अर्को व्यक्ति, उही काम" थिच्नुहोस्; काम, घण्टा र फोटो उस्तै रहन्छन्।', 'Tap "Record in my name". If several people did the same work, tap "Another person, same work"; the work, hours and photos stay filled in.'],
          ['त्यसपछि सुपरिवेक्षकले स्वीकृत गर्छन्। स्वीकृत घण्टाको मात्र ज्याला आउँछ, र घरको पालोमा गनिन्छ।', 'A supervisor then approves it. Only approved hours are paid and counted in the household’s turn.'],
        ],
        tip: ['काम गर्ने व्यक्तिको नाम सबैले देख्ने ठाउँमा आउँदैन: सबैले घर नम्बरअनुसार घण्टा मात्र देख्छन्, व्यक्तिले आफ्नो काम "मेरो" मा। नमुनामा: "मेरो" मा गीता (लेखापाल) छान्नुहोस्; जुनसुकै फोटो छान्न सकिन्छ, त्यो फोनबाहिर जाँदैन।', 'The worker’s name never appears where everyone can see: everyone sees hours by house number, each person their own work under Mine. In the sample: choose गीता (ledger keeper) under Mine; any photo will do, and it does not leave the phone.'],
        open: { route: 'worklog', label: ['काम र घण्टा लेख्ने खोल्नुहोस्', 'Open Record work hours'] },
      },
      {
        id: 'nosignal', title: ['सिग्नल नहुँदा फाराम भर्ने', 'Filling forms with no signal'],
        who: ['लेखापाल, सुपरिवेक्षक, प्रकृति हेरालु', 'Ledger keeper, supervisor, nature guardian'],
        steps: [
          ['कामको घण्टा र पानी-वर्षा नाप सिग्नल नभए पनि भर्न सकिन्छ। "मेरो नाममा लेख्नुहोस्" थिच्दा फोनमा राखियो भनेर देखिन्छ।', 'Work hours and water-and-rain readings can be filled in with no signal. When you tap "Record in my name" it says the entry is kept on the phone.'],
          ['माथि ↑ र सङ्ख्या देखिन्छ: त्यति इन्ट्री पठाउन बाँकी छन्। काम बाँकीको "पठाउन बाँकी" मा तिनको सूची छ।', 'An ↑ with a number shows at the top: that many entries are waiting to be sent. "Waiting to send" in To do lists them.'],
          ['सिग्नल आएपछि एप खोल्दा ती आफैं पठाइन्छन्, फोटोसहित। "अहिले पठाउनुहोस्" थिचेर पनि पठाउन सकिन्छ। एउटै इन्ट्री दुई पटक लेखिँदैन।', 'When there is signal and the app is open they are sent by themselves, with their photos. You can also tap "Send now". An entry is never recorded twice.'],
          ['नियमले नमिल्ने इन्ट्री (जस्तै एक दिनमा १२ घण्टाभन्दा बढी) कारणसहित रातो देखिन्छ। हटाएर, मिलाएर फेरि लेख्नुहोस्।', 'An entry the rules refuse (for example more than 12 hours in a day) shows in red with the reason. Remove it, put it right and record it again.'],
          ['पठाउनुअघि फोन नफेर्नुहोस् र एपको डेटा नमेटाउनुहोस्; पठाउन बाँकी इन्ट्री त्यही फोनमा मात्र हुन्छन्।', 'Do not change phones or clear the app’s data before they are sent; entries waiting to be sent exist only on that phone.'],
        ],
        tip: ['बिलको फोटो पढ्न, भुक्तानीमा हस्ताक्षर र स्वीकृति गर्न सिग्नल चाहिन्छ, किनकि ती ताजा हिसाब हेरेर गरिन्छन्।', 'Reading a bill’s photo, signing payments and approving hours need signal, because they are done against the latest figures.'],
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
        id: 'moneymoves', title: ['चौतारीले पैसा सार्दैन', 'The app never moves money'],
        steps: [
          ['"सूचना दिनुहोस्", "प्रश्न सोध्नुहोस्" वा "स्वीकृत गर्नुहोस्" थिच्दा हिसाबमा सूचना वा सहमति मात्र दर्ता हुन्छ। पैसा आफैं जाँदैन।', 'Tapping "Give notice", "Ask" or "Approve" records a notice or an approval, nothing more. No money moves by itself.'],
          ['पैसा बैंक वा नगदबाट दुई हस्ताक्षरपछि पदाधिकारीले दिन्छन्, अनि मात्र चौतारीमा भुक्तानी देखिन्छ।', 'Money is paid out through the bank or in cash by officers after two signatures, and only then shows as a payment in चौतारी.'],
          ['चौतारीमा देखिएको अङ्क बैंक वा हातको नगदसँग नमिले "प्रश्न सोध्नुहोस्"; मिल्नुपर्ने हो।', 'If a figure in चौतारी does not match the bank or the cash in hand, ask; they should match.'],
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
        tip: ['पुष्टि भएको हरेक इन्ट्रीमा "एआईले पढ्यो" र व्यक्तिले कुन कुरा सच्यायो भन्ने सबैले देख्छन्। एआई कति पटक ठीक थियो भन्ने गन्ती पनि सार्वजनिक हुन्छ। बिल पढ्ने काम अहिले नमुना बिलमा मात्र जाँचिएको छ; वास्तविक बिलमा सुरुमा धेरै "!" आउन सक्छ।', 'Every confirmed entry shows everyone that the AI read it and what the person corrected. A count of how often the AI was right is public too. The reader has so far been tested on sample bills only; real bills may show many "!" at first.'],
        open: { route: 'capture', label: ['बिलको फोटोबाट हिसाब खोल्नुहोस्', 'Open From a bill’s photo'] },
      },
    ],
  },
  {
    title: ['शब्दकोश', 'Words used here'],
    topics: [
      {
        id: 'glossary', title: ['शब्दको अर्थ', 'What the words mean'],
        steps: [
          ['शेयर: सहकारीको सदस्य हुँदा लिने रु १०० को एक कित्ता। प्रत्येक सदस्यको एक।', 'Share: the Rs 100 each member takes on joining the cooperative; one per member.'],
          ['परियोजना ऋण: सदस्यले सहकारीका परियोजनामा लगाएको पैसा। सबैलाई एउटै ब्याजदर।', 'Project loan: money a member lends to the cooperative’s projects, at one rate for everyone.'],
          ['पर्म: घरहरूबीच काम साटासाट। कुन घरले कति दिन दियो र पायो।', 'Parma: exchange of work between households: days each house gave and received.'],
          ['पालो: पैसा आउने कामको अवसर घरअनुसार पालैपालो बाँड्ने क्रम।', 'Turn (पालो): the order in which paid work is shared out among households.'],
          ['गुठी कोष: चौथे गुठीको स्थायी कोष; यसको मूल रकम खर्च हुँदैन।', 'Guthi fund: the Chauthe Guthi’s permanent fund; its principal is not spent.'],
          ['संरक्षित पूँजी फिर्ता कोष: वर्षान्तको बचतको ३०%, पूँजी लगाउने सदस्यलाई फिर्ता गर्न छुट्याइने।', 'Protected capital return fund: 30% of the year-end surplus, set aside to return to members who put in capital.'],
          ['औंठाछाप (hash): हरेक इन्ट्रीको छाप। कुनै अङ्क बदलिए छाप मिल्दैन, त्यसैले बदलिएको तुरुन्तै थाहा हुन्छ।', 'Fingerprint (hash): a seal on every entry. If any figure is changed the seal no longer matches, so a change shows at once.'],
        ],
        tip: ['यी अर्थ विनियम ४.१५ को मस्यौदाअनुसार हुन्; भेलाले बदलेमा यहाँ पनि बदलिन्छ।', 'These meanings follow the draft bylaws v4.15; if the assembly changes them, this page changes too.'],
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
        steps: [['एपले पछिल्लो पटक भरिएको हिसाब देखाउँछ र माथि "इन्टरनेट छैन" लेख्छ। जङ्गलमा भरेका काम र नापका फाराम फोनमा राखिन्छन् र सिग्नल आएपछि आफैं पठाइन्छन् (माथिको ↑ सङ्ख्या)।', 'The app shows the last saved figures and says "Offline" at the top. Work and reading forms filled in the forest are kept on the phone and sent by themselves when there is signal (the ↑ number at the top).']],
      },
      {
        id: 'sample', title: ['यी नाम र अङ्क साँचो हुन्?', 'Are these names and figures real?'],
        steps: [['होइनन्। नमुनाका सबै नाम र अङ्क काल्पनिक हुन्। भेलाले स्वीकृत गरे मात्र वास्तविक हिसाब राखिन्छ।', 'No. Every name and figure in the sample is made up. Real records start only if the assembly approves.']],
      },
      {
        id: 'problem', title: ['गलत अङ्क देखेँ भने', 'If you see a wrong figure'],
        steps: [
          ['खर्चको अङ्क हो भने हाम्रो पैसामा त्यो भुक्तानीमुनि "प्रश्न सोध्नुहोस्" थिच्नुहोस्।', 'If it is a payment, tap "Ask about this" under it in Our money.'],
          ['एपले केही गलत देखाएको वा चलेन भने हिसाब राख्ने पदाधिकारीलाई भन्नुहोस्; के-कहाँ देखिएको हो भन्ने स्क्रिनको फोटो पठाउन सहज हुन्छ।', 'If the app itself shows something wrong or breaks, tell the record keeper; a screenshot of what you saw helps.'],
          ['सच्याइएको भए पुरानो इन्ट्री मेटिँदैन; नयाँ "सच्याइएको" इन्ट्री थपिन्छ।', 'A fix does not erase the old entry; a new correction entry is added.'],
        ],
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
        {PARTS.map((p, i) => <button key={i} onClick={() => document.getElementById(`part-${i}`)?.scrollIntoView({ behavior: 'smooth' })}>{T(p.title)}</button>)}
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
      <footer class="about">
        <h2>{np ? 'यो एपबारे' : 'About this app'}</h2>
        <p>{np ? 'संस्करण' : 'Version'} {digits(__VERSION__)} · {np ? 'बनेको मिति' : 'Built'} {bsDate(__BUILD_DATE__)}</p>
        <p>{np ? 'लागू नियम: ' : 'Rules in use: '}{T(BYLAWS)}</p>
        <p>{np
          ? 'गलत अङ्क देख्नुभयो वा एप चलेन भने हिसाब राख्ने पदाधिकारीलाई भन्नुहोस्; स्क्रिनको फोटो भए सजिलो हुन्छ।'
          : 'If you see a wrong figure or the app does not work, tell the record keeper; a screenshot helps.'}</p>
      </footer>
    </Screen>
  );
}
