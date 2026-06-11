import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/colors.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isObscure;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final String? preFixIcon;
  final String? Function(String?)? validator;
  final bool enabled; // ✅ New line

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.isObscure = false,
    required this.keyboardType,
    this.suffixIcon,
    this.preFixIcon,
    this.validator,
    this.enabled = true, // ✅ Default value
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.primaryColor, width: 1.w),
      ),
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.isObscure,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.jost(
            color: AppColors.hintTextColor,
            fontSize: 14.sp,
          ),
          suffixIcon: widget.suffixIcon != null
              ? IconTheme(
            data: IconThemeData(color: AppColors.primaryTextColor),
            child: widget.suffixIcon!,
          )
              : null,
          prefixIcon: widget.preFixIcon != null
              ? Padding(
            padding: EdgeInsets.all(10.sp),
            child: SizedBox(
              height: 10.sp,
              width: 10.sp,
              child: SvgPicture.asset(
                widget.preFixIcon!,
                color: AppColors.primaryColor,
              ),
            ),
          )
              : null,
          fillColor: AppColors.backgroundColor,
          filled: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: 10.h,
          ), // ✅ Yeh height manage karega
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(10.r)),
          ),
        ),
        validator: widget.validator,
      ),
    );
  }
}
