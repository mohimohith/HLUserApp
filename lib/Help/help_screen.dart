import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../compat/app_state.dart';
import '../data/repositories/repositories.dart';
import '../utils/colors.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../Provider/language_provider.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String callingNumber = 'Loading...!';
  String whatsapp_Number = 'Loading...!';
  String support_email = 'Loading...!';

  String branchId = '';
  String branchName = "";

  @override
  void initState() {
    super.initState();
    fetchLocation();
  }

  Future<void> fetchLocation() async {
    branchId = AppState.branchIdOrEmpty;
    branchName = AppState.branchName ?? "";
    if (branchId.isEmpty) return;
    try {
      final home = await Repos.home.getHome(branchId);
      final s = home.settings;
      setState(() {
        callingNumber = (s.helpCallNumber ?? '').isNotEmpty
            ? s.helpCallNumber! : 'Not available';
        whatsapp_Number = (s.helpWhatsapp ?? '').isNotEmpty
            ? s.helpWhatsapp! : 'Not available';
        support_email = (s.helpEmail ?? '').isNotEmpty
            ? s.helpEmail! : 'Not available';
      });
    } catch (e) {
      debugPrint("Error loading help info: $e");
    }
  }

  // Helper method to get text based on language
  String getText(BuildContext context, String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }


  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message ${getText(context, "copied to clipboard", "క్లిప్‌బోర్డ్‌కు కాపీ చేయబడింది")}'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    // Remove any non-digit characters from the phone number
    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    final url = Uri.parse("https://wa.me/$cleanedNumber");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(getText(context, 'Could not launch WhatsApp', 'వాట్సాప్ ప్రారంభించడం విఫలమైంది')),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: 17.h),
          // Header
          Container(
            width: double.infinity,
            height: 60.h,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: Offset(0, 4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding:  EdgeInsets.only(top: 14.h),
              child: Row(
                children: [
                  SizedBox(width: 16.w),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 25.h,
                      width: 28.w,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(left: 7.w),
                          child: Icon(Icons.arrow_back_ios,
                              size: 15.sp, color: AppColors.iconColor),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Consumer<LanguageProvider>(
                    builder: (context, languageProvider, child) {
                      return Text(
                        getText(context, "Help", "సహాయం"),
                        style: GoogleFonts.jost(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 👇 Header ke niche scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  children: [
                    SizedBox(height: 30.h),
                    Image.asset('assets/images/help_image.png', width: 270.w),

                    SizedBox(height: 20.h),

                    // Call Support Card
                    _buildContactCard(
                      icon: Icons.phone_in_talk,
                      title: getText(context, "Call Support", "కాల్ సపోర్ట్"),
                      subtitle: getText(context, "Talk to our support team", "మా సపోర్ట్ బృందంతో మాట్లాడండి"),
                      value: callingNumber,
                      color: AppColors.primaryColor,
                      onTap: () {
                        if (callingNumber != 'Loading...!' &&
                            callingNumber != getText(context, 'Not available', 'అందుబాటులో లేదు') &&
                            callingNumber != getText(context, 'Error loading', 'లోడ్ చేయడంలో లోపం')) {
                          _makePhoneCall(callingNumber);
                        }
                      },
                      onCopy: () {
                        if (callingNumber != 'Loading...!' &&
                            callingNumber != getText(context, 'Not available', 'అందుబాటులో లేదు') &&
                            callingNumber != getText(context, 'Error loading', 'లోడ్ చేయడంలో లోపం')) {
                          _copyToClipboard(callingNumber, getText(context, 'Phone number', 'ఫోన్ నంబర్'));
                        }
                      },
                    ),

                    SizedBox(height: 16.h),

                    // WhatsApp Support Card
                    _buildContactCard(
                      icon: Icons.chat,
                      title: getText(context, "WhatsApp Support", "వాట్సాప్ సపోర్ట్"),
                      subtitle: getText(context, "Message us on WhatsApp", "మాకు వాట్సాప్‌లో సందేశం పంపండి"),
                      value: whatsapp_Number,
                      color: Colors.green,
                      onTap: () {
                        if (whatsapp_Number != 'Loading...!' &&
                            whatsapp_Number != getText(context, 'Not available', 'అందుబాటులో లేదు') &&
                            whatsapp_Number != getText(context, 'Error loading', 'లోడ్ చేయడంలో లోపం')) {
                          _launchWhatsApp(whatsapp_Number);
                        }
                      },
                      onCopy: () {
                        if (whatsapp_Number != 'Loading...!' &&
                            whatsapp_Number != getText(context, 'Not available', 'అందుబాటులో లేదు') &&
                            whatsapp_Number != getText(context, 'Error loading', 'లోడ్ చేయడంలో లోపం')) {
                          _copyToClipboard(whatsapp_Number, getText(context, 'WhatsApp number', 'వాట్సాప్ నంబర్'));
                        }
                      },
                    ),

                    SizedBox(height: 16.h),

                    // Email Support Card
                    _buildContactCard(
                      icon: Icons.email,
                      title: getText(context, "Email Support", "ఇమెయిల్ సపోర్ట్"),
                      subtitle: getText(context, "Send us an email", "మాకు ఇమెయిల్ పంపండి"),
                      value: support_email,
                      color: AppColors.warningColor,
                      onTap: () {
                        if (support_email != 'Loading...!' &&
                            support_email != getText(context, 'Not available', 'అందుబాటులో లేదు') &&
                            support_email != getText(context, 'Error loading', 'లోడ్ చేయడంలో లోపం')) {
                          _sendEmail(support_email);
                        }
                      },
                      onCopy: () {
                        if (support_email != 'Loading...!' &&
                            support_email != getText(context, 'Not available', 'అందుబాటులో లేదు') &&
                            support_email != getText(context, 'Error loading', 'లోడ్ చేయడంలో లోపం')) {
                          _copyToClipboard(support_email, getText(context, 'Email address', 'ఇమెయిల్ చిరునామా'));
                        }
                      },
                    ),

                    SizedBox(height: 30.h),

                    // Help Text
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Consumer<LanguageProvider>(
                        builder: (context, languageProvider, child) {
                          return Text(
                            getText(
                                context,
                                "Our support team is available to help you with any questions or issues you might have. Feel free to reach out to us through any of the channels above.",
                                "మీకు ఎలాంటి ప్రశ్నలు లేదా సమస్యలు ఉంటే మా సహాయక బృందం మీకు సహాయం చేయడానికి సిద్ధంగా ఉంది. పైన ఉన్న ఏ ఛానెల్ ద్వారా అయినా మాతో సంప్రదించండి."
                            ),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jost(
                              fontSize: 14.sp,
                              color: AppColors.hintTextColor,
                              height: 1.5,
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Color color,
    required VoidCallback onTap,
    required VoidCallback onCopy,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              width: 50.w,
              height: 50.h,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jost(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.jost(
                      fontSize: 12.sp,
                      color: AppColors.hintTextColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    value,
                    style: GoogleFonts.jost(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: value == 'Loading...!' ||
                          value == getText(context, 'Not available', 'అందుబాటులో లేదు') ||
                          value == getText(context, 'Error loading', 'లోడ్ చేయడంలో లోపం')
                          ? AppColors.errorColor
                          : AppColors.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(20.r),
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Icon(
                  Icons.content_copy,
                  size: 20.sp,
                  color: AppColors.hintTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}