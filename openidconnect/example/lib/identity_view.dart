import 'package:flutter/material.dart';
import 'package:openidconnect/openidconnect.dart';

class IdentityView extends StatelessWidget {
  final AuthorizationResponse identity;
  IdentityView(this.identity);

  @override
  Widget build(BuildContext context) {
    final captionTheme = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: EdgeInsets.all(15),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Access Token:",
                  softWrap: true,
                  style: captionTheme,
                ),
                Text(
                  identity.accessToken,
                )
              ],
            ),
            Row(
              children: [
                Text(
                  "Identity Token:",
                  style: captionTheme,
                ),
                Text(
                  identity.idToken,
                )
              ],
            ),
            Row(
              children: [
                Text(
                  "Token Type:",
                  style: captionTheme,
                ),
                Text(
                  identity.tokenType,
                )
              ],
            ),
            Row(
              children: [
                Text(
                  "Expires At:",
                  style: captionTheme,
                ),
                Text(
                  identity.expiresAt.toIso8601String(),
                )
              ],
            ),
            Row(
              children: [
                Text(
                  "Refresh Token:",
                  style: captionTheme,
                ),
                Text(
                  identity.refreshToken ?? "Not included",
                )
              ],
            ),
            Row(
              children: [
                Text(
                  "State:",
                  style: captionTheme,
                ),
                Text(
                  identity.state ?? "Not Included",
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
