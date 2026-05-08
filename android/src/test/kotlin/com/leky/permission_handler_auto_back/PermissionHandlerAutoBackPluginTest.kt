package com.leky.permission_handler_auto_back

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class PermissionHandlerAutoBackPluginTest {
    @Test
    fun onMethodCall_unknownMethod_returnsNotImplemented() {
        val plugin = PermissionHandlerAutoBackPlugin()
        val call = MethodCall("doesNotExist", null)
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(call, result)

        Mockito.verify(result).notImplemented()
    }

    @Test
    fun onMethodCall_openSettingsAndAutoReturn_withoutPermissionArg_returnsArgError() {
        val plugin = PermissionHandlerAutoBackPlugin()
        val call = MethodCall("openSettingsAndAutoReturn", null)
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(call, result)

        Mockito.verify(result).error(
            Mockito.eq("ARG_ERR"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }
}
