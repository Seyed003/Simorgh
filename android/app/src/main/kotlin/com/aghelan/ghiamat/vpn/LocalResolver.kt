/*
 * Adapted from sing-box-for-android (GPL-3.0-or-later), Copyright (C) SagerNet.
 */
package com.aghelan.ghiamat.vpn

import android.net.DnsResolver
import android.os.Build
import android.os.CancellationSignal
import android.system.ErrnoException
import androidx.annotation.RequiresApi
import io.nekohasekai.libbox.ExchangeContext
import io.nekohasekai.libbox.LocalDNSTransport
import java.net.InetAddress
import java.net.UnknownHostException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors

/**
 * Resolves the `local` DNS server through Android's resolver bound to the
 * underlying network, so lookups never loop back into the tunnel.
 */
object LocalResolver : LocalDNSTransport {
    private const val RCODE_NXDOMAIN = 3
    private val executor = Executors.newCachedThreadPool()

    override fun raw(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun exchange(ctx: ExchangeContext, message: ByteArray) {
        val network = DefaultNetworkMonitor.defaultNetwork ?: error("missing default network")
        val latch = CountDownLatch(1)
        val signal = CancellationSignal()
        var failure: Throwable? = null
        ctx.onCancel {
            signal.cancel()
            latch.countDown()
        }
        DnsResolver.getInstance().rawQuery(
            network,
            message,
            DnsResolver.FLAG_NO_RETRY,
            executor,
            signal,
            object : DnsResolver.Callback<ByteArray> {
                override fun onAnswer(answer: ByteArray, rcode: Int) {
                    if (rcode == 0) ctx.rawSuccess(answer) else ctx.errorCode(rcode)
                    latch.countDown()
                }

                override fun onError(error: DnsResolver.DnsException) {
                    val cause = error.cause
                    if (cause is ErrnoException) ctx.errnoCode(cause.errno) else failure = error
                    latch.countDown()
                }
            },
        )
        latch.await()
        failure?.let { throw it }
    }

    override fun lookup(ctx: ExchangeContext, network: String, domain: String) {
        val underlying = DefaultNetworkMonitor.defaultNetwork ?: error("missing default network")
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val answer = try {
                underlying.getAllByName(domain)
            } catch (e: UnknownHostException) {
                ctx.errorCode(RCODE_NXDOMAIN)
                return
            }
            ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
            return
        }
        val latch = CountDownLatch(1)
        val signal = CancellationSignal()
        var failure: Throwable? = null
        ctx.onCancel {
            signal.cancel()
            latch.countDown()
        }
        val callback = object : DnsResolver.Callback<List<InetAddress>> {
            override fun onAnswer(answer: List<InetAddress>, rcode: Int) {
                if (rcode == 0) {
                    ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
                } else {
                    ctx.errorCode(rcode)
                }
                latch.countDown()
            }

            override fun onError(error: DnsResolver.DnsException) {
                val cause = error.cause
                if (cause is ErrnoException) ctx.errnoCode(cause.errno) else failure = error
                latch.countDown()
            }
        }
        val type = when {
            network.endsWith("4") -> DnsResolver.TYPE_A
            network.endsWith("6") -> DnsResolver.TYPE_AAAA
            else -> null
        }
        if (type != null) {
            DnsResolver.getInstance().query(underlying, domain, type, DnsResolver.FLAG_NO_RETRY, executor, signal, callback)
        } else {
            DnsResolver.getInstance().query(underlying, domain, DnsResolver.FLAG_NO_RETRY, executor, signal, callback)
        }
        latch.await()
        failure?.let { throw it }
    }
}
